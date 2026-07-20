# 后端开发规范

本页定义 VibeBase 后端的编码规范：分层职责、统一响应、异常处理、参数校验，以及「新增一个端点」的完整步骤。所有规范都源于现有代码，照着写即可与既有模块保持一致。

## 三层职责回顾

VibeBase 后端严格遵循 **Router → Service → DAO** 分层（详见 [项目结构](./structure)）。

![后端三层架构](/diagrams/three-layer.svg)

每一层只做份内的事：

| 层 | 文件位置 | 职责 | 禁止 |
| --- | --- | --- | --- |
| **Router** | `api/v1/xxx.py` | 路径声明、HTTP 方法、tags、参数校验、认证依赖、响应包装 | 写复杂业务逻辑、直接操作 Session 做 CRUD |
| **Service** | `api/services/xxx.py` | 业务逻辑编排、跨 DAO 协作、调用外部服务 | 直接返回 `resp_200`、关心 HTTP 状态码 |
| **DAO** | `database/dao/xxx.py` | 纯数据库 CRUD | 业务判断（如「余额是否充足」）、HTTP 异常 |

## 统一响应模型

所有**非流式**接口必须返回 `UnifiedResponseModel`，定义在 `schema/schemas.py`：

```python
class UnifiedResponseModel(BaseModel, Generic[DataT]):
    status_code: int
    status_message: str
    data: DataT = None
```

序列化后的响应体：

```json
{
  "status_code": 200,
  "status_message": "SUCCESS",
  "data": { ... },
  "detail": "（兼容旧前端，全局异常处理器会补上）"
}
```

::: warning 唯一例外
对话接口 `POST /api/v1/chat` 返回 `text/event-stream` 的 SSE 流，不走 `UnifiedResponseModel`。详见 [聊天与流式](./chat-streaming)。
:::

### 响应包装助手

`schema/schemas.py` 提供四个工厂函数，Router 层必须用它们构造响应：

| 函数 | 签名 | 用途 |
| --- | --- | --- |
| `resp_200` | `resp_200(data=None, message="SUCCESS")` | 成功响应 |
| `resp_400` | `resp_400(data=None, message="BAD REQUEST")` | 请求参数/业务错误 |
| `resp_404` | `resp_404(data=None, message="NOT FOUND")` | 资源不存在 |
| `resp_500` | `resp_500(code=500, data=None, message="BAD REQUEST")` | 服务器内部错误 |

用法示例（来自 `api/v1/points.py`）：

```python
from schema.schemas import resp_200

@router.get("/points/info")
async def points_info(user: UserTable = Depends(UserService.get_current_user)):
    account = PointAccountDao.get_or_create(user.user_id)
    return resp_200({
        "remaining_points": int(account.points or 0),
        "used_points": int(account.total_consumed or 0),
    })
```

## 全局异常处理器

`main.py` 的 `register_exception_handlers` 注册了三个全局处理器，将所有异常统一为 `UnifiedResponseModel` 格式（并补 `detail` 兼容旧前端）：

| 异常 | HTTP 状态 | 行为 |
| --- | --- | --- |
| `RequestValidationError` | 422 | 聚合 Pydantic 校验错误为 `字段: 错误信息; 字段: 错误信息` |
| `HTTPException` | 原 status_code | `status_message = str(exc.detail)`，透传原状态码 |
| `Exception`（兜底） | 500 | 记录日志，返回 `服务器内部错误，请稍后重试`，不暴露堆栈 |

```python
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    # ... 聚合错误消息 ...
    content = UnifiedResponseModel(status_code=422, status_message=message, data=None).model_dump()
    content["detail"] = message
    return JSONResponse(status_code=422, content=content)

@app.exception_handler(Exception)
async def unhandled_exception_handler(request, exc):
    logger.error(f"未捕获异常: {request.method} {request.url.path} -> {exc}", exc_info=True)
    content = UnifiedResponseModel(status_code=500, status_message="服务器内部错误，请稍后重试", data=None).model_dump()
    return JSONResponse(status_code=500, content=content)
```

::: tip 业务错误的推荐写法
在 Service 层用 `raise HTTPException(status_code=402, detail="积分余额不足，请充值后再试")` 抛错，全局处理器会自动转成 `UnifiedResponseModel`，前端读 `status_message` 即可。**不要**手动 `try/except` 后返回 `resp_500`。
:::

## 中间件链

`main.py` 的 `register_middleware` 按顺序注册（执行顺序为「注册的反序」，最内层最先执行）：

1. **CORS** — 显式放行 `localhost:5173~5176`（VibeAdmin/Vibe-Mp-H5/VibeBase/VibeApp），避免 `*` 与 `credentials` 冲突
2. **`mark_whitelist_paths`** — 请求路径以 `app_settings.whitelist_paths` 任一前缀开头时，标记 `request.state.is_whitelisted = True`（供认证依赖读取）
3. **`rate_limit_middleware`** — Redis 限流（`vbase:{ip}:{path}`，120 次/分钟），超限返回 429，Redis 异常时自动放行

## 路由聚合与 tags

所有子路由在 `api/router.py` 的 `include_v1_routes()` 中聚合，统一前缀 `/api/v1` 并打 tags（用于 `/docs` 分组）：

```python
router.include_router(chat.router, prefix="/api/v1", tags=["对话"])
router.include_router(user.router, prefix="/api/v1", tags=["用户"])
router.include_router(points.router, prefix="/api/v1", tags=["积分明细"])
router.include_router(recharge.router, prefix="/api/v1", tags=["充值"])
# ... 共 20 个模块
```

::: info tags 是中文
VibeBase 有意在 `api/router.py` 用中文 tags（`对话`、`用户`、`积分明细`、`充值`...），让 Swagger `/docs` 页面对运营和产品更友好。
:::

## 端到端示例：积分流水查询

以「查询当前用户的积分流水」为例，展示三层如何协作。完整代码见 `api/v1/points.py`。

### 1. Router 层

```python
# api/v1/points.py
@router.post("/points/transactions")
async def points_transactions(
    page: int = Body(1),
    limit: int = Body(20),
    user: UserTable = Depends(UserService.get_current_user),  # 认证依赖
):
    # 1. 调 DAO 取原始数据（不在这里写 SQL）
    rows = PointTransactionDao.list_by_user(user.user_id, limit=1000)
    # 2. 把 ORM 对象转成响应字典（字段映射是 Router 的职责）
    items = [
        {
            "id": r.id,
            "transaction_type": "earn" if r.amount > 0 else "spend",
            "points_amount": abs(r.amount),
            "balance_after": r.balance_after,
            "type": r.type,
            "description": r.remark or r.ability or r.type,
            "create_time": r.created_at.isoformat() if r.created_at else "",
        }
        for r in rows
    ]
    # 3. 分页 + 包装统一响应
    start = (page - 1) * limit
    return resp_200(items[start : start + limit])
```

### 2. DAO 层

```python
# database/dao/point.py
class PointTransactionDao:
    @classmethod
    def list_by_user(cls, user_id: str, type_filter=None, limit=100):
        with Session(engine) as session:
            stmt = select(PointTransaction).where(PointTransaction.user_id == user_id)
            if type_filter:
                stmt = stmt.where(PointTransaction.type == type_filter)
            stmt = stmt.order_by(PointTransaction.created_at.desc()).limit(limit)
            return session.exec(stmt).all()
```

### 3. Model 层

模型定义在 `vibe_common/models/point_transaction.py`（详见 [数据模型](./data-models)）。

## 如何新增一个端点

以「新增一个工单详情查询接口」为例：

::: details 完整步骤

**第一步：定义 Schema（可选）**

如果请求体复杂，在 `schema/` 下定义 Pydantic 模型。简单查询用 query/path 参数即可。

```python
# schema/ticket.py
from pydantic import BaseModel, Field

class TicketCreateReq(BaseModel):
    title: str = Field(max_length=200, description="工单标题")
    content: str = Field(description="工单内容")
    priority: str = Field("medium", description="优先级 high/medium/low")
```

**第二步：实现 DAO（如需新查询）**

在 `database/dao/ticket.py` 加一个类方法，只做 CRUD：

```python
@classmethod
def get_by_no(cls, ticket_no: str) -> Optional[Ticket]:
    with Session(engine) as session:
        return session.exec(
            select(Ticket).where(Ticket.ticket_no == ticket_no)
        ).first()
```

**第三步：在 Router 写端点**

在 `api/v1/ticket.py` 新增端点，注入认证依赖，调用 DAO，包装响应：

```python
@router.get("/ticket/{ticket_no}")
async def get_ticket(
    ticket_no: str,
    user: UserTable = Depends(UserService.get_current_user),
):
    ticket = TicketDao.get_by_no(ticket_no)
    if not ticket or ticket.user_id != user.user_id:
        return resp_404("工单不存在")
    return resp_200({...})
```

**第四步：注册路由（若新文件）**

如果创建了新的 `api/v1/xxx.py`，需在 `api/router.py` 的 `include_v1_routes()` 中导入并 `include_router(..., prefix="/api/v1", tags=[...])`。

**第五步：验证**

访问 `http://localhost:8081/docs`，在对应 tag 下找到新端点，点击「Try it out」测试。

:::

## Pydantic Schema 约定

- **请求模型**放 `schema/`（如 `schema/chat.py` 的 `ConversationReq`），用 `Field(description=...)` 描述
- **可选字段**用 `Optional[T] = Field(None, ...)` 或 `= Field(False, ...)` 提供默认值
- **校验约束**用 `max_length`、`ge`、`le` 等，校验失败会自动走全局 422 处理器
- **响应模型**优先复用 `UnifiedResponseModel`，避免为每个端点新建响应类

```python
# schema/chat.py — 真实示例
class ConversationReq(BaseModel):
    user_input: str = Field(description="用户的问题")
    dialog_id: str = Field(description="对话的ID值")
    file_url: Optional[str] = Field(None, description="上传文件的oss链接")
    open_search: Optional[bool] = Field(False, description="是否开启联网搜索")
    open_reasoning: Optional[bool] = Field(False, description="是否开启深度思考")
    open_research: Optional[bool] = Field(False, description="是否开启研究模式")
    llm_id: Optional[str] = Field(None, description="指定使用的LLM模型ID")
```

## 认证依赖

保护端点用以下两种依赖之一（详见 [认证机制](./authentication)）：

| 依赖 | 返回 | 适用 |
| --- | --- | --- |
| `Depends(get_login_user)` | `UserPayload`（含 `user_id`/`user_name`/`user_role`/`is_admin()`） | 只需身份、不查库的接口 |
| `Depends(UserService.get_current_user)` | `UserTable`（完整用户对象） | 需要读用户字段的接口 |

```python
from api.services.user import UserPayload, get_login_user, UserService

@router.post("/xxx")
async def handler(
    req: SomeReq = Body(...),
    login_user: UserPayload = Depends(get_login_user),  # 轻量，不查库
):
    ...

@router.get("/profile")
async def profile(user: UserTable = Depends(UserService.get_current_user)):
    # user.user_id / user.user_name / user.balance 都可用
    ...
```

## 日志

用 `loguru` 的 `logger`，不要用 `print`：

```python
from loguru import logger

logger.info(f"用户 {user_id} 创建订单 {order_no}")
logger.error(f"扣减积分失败: {e}")
logger.warning(f"支付回调验签失败: order_no={order_no}")
```

## 接下来

- [项目结构](./structure) — 各目录的完整职责
- [认证机制](./authentication) — `get_login_user` 的完整流程
- [数据模型](./data-models) — DAO 操作的表结构
- [API 参考](../api/user) — 各端点的请求/响应示例
