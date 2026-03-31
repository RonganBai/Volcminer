# VolcMiner Ubuntu Aggregator

这个目录是从当前工作区隔离出来的服务端化副本，用来承接 Ubuntu 24 上的集中采集、分析和统一 API 输出。

## 目标

- 不修改原始程序
- 避开现有 `10.0.0.52:8000`
- 让 Ubuntu 服务器承担采集、聚合、分析、缓存
- 让 Windows/安卓只调用统一接口展示数据

## 当前实现

- 零依赖 Node.js 服务，默认监听 `18080`
- `collector` 支持受控并发采集，默认并发上限 `500`
- `analyzer` 统一计算算力、温度、在线状态、告警
- `storage` 将状态和历史快照落盘到 `data/cache.json`
- `scheduler` 以 `15` 分钟级别驱动扫描，并在 HashSentry 活跃或资源紧张时自动延后
- `resource guard` 检查 CPU load、可用内存和 HashSentry 扫描 worker
- 只读 API：
  - `GET /health`
  - `GET /api/miners`
  - `GET /api/miners/:id/status`
  - `GET /api/miners/:id/overview`
  - `GET /api/dashboard/summary`
  - `GET /api/alerts`
  - `GET /api/system/health`
  - `GET /api/system/scheduler`
  - `POST /api/admin/refresh`

`POST /api/admin/refresh` 只会触发重新采集，不会下发任何写操作到矿机。

## 启动

需要 Node.js 20+：

```bash
cp .env.example .env
node src/server.js
```

默认启动地址：

```text
http://0.0.0.0:18080
```

默认调度策略：

- 首次启动后延迟 `2` 分钟进入等待态
- 每 `15` 分钟尝试发起一轮扫描
- 如果 HashSentry 扫描 worker 活跃，或系统 load / 可用内存超过阈值，本轮自动延后
- API 只读取缓存，不会因为前端请求触发大规模即时补采

## 目录

- `src/collector`: 矿机采集器和适配器
- `src/analyzer`: 聚合分析
- `src/storage`: 状态缓存与历史快照
- `config/miners.json`: 矿机清单配置
- `data/mock`: 本地 mock 数据
- `deploy/systemd`: Ubuntu service 模板
- `deploy/nginx`: 独立反向代理配置模板
- `reference/volcminer_remote_index.js`: 原始前端包参考副本

## 配置矿机

编辑 [config/miners.json](/Users/keshi/OneDrive/Documents/Playground/volcminer-server-migration/config/miners.json)。

每台矿机支持两种接入方式：

1. `source: "mock"`
2. `source: "volcminer-http"`

### Mock 示例

```json
{
  "id": "miner-demo-01",
  "name": "Demo Miner 01",
  "source": "mock",
  "mockFile": "./data/mock/miner-demo-01.json"
}
```

### HTTP 示例

```json
{
  "id": "miner-01",
  "name": "Rack A / Miner 01",
  "source": "volcminer-http",
  "baseUrl": "http://10.0.0.61",
  "timeoutMs": 4000,
  "endpoints": {
    "status": "/api/status",
    "overview": "/api/overview",
    "monitor": "/api/monitor"
  },
  "headers": {
    "Authorization": "Bearer change-me"
  }
}
```

如果真实矿机接口路径不同，直接改 `endpoints` 就可以，不需要改采集器代码。

## 关键环境变量

- `PORT=18080`
- `POLL_INTERVAL_MS=900000`
- `SCHEDULER_TICK_MS=30000`
- `SCAN_CONCURRENCY=300`
- `SCHEDULER_INITIAL_DELAY_MS=120000`
- `SKIP_IF_HASHSENTRY_ACTIVE=true`
- `CPU_LOAD_GUARD_RATIO=1.8`
- `MIN_AVAILABLE_MEMORY_MB=2048`
- `MAX_HASHSENTRY_SCAN_PROCESSES=64`

## 与现有 `8000` 端口隔离

- 本服务默认端口是 `18080`
- `systemd` 模板和 `nginx` 模板都不会占用 `8000`
- 如果 `18080` 也冲突，只需改 `.env` 里的 `PORT`

## Ubuntu 24 直接部署

可直接参考：

- [DEPLOY_UBUNTU_10.0.0.52.md](/Users/keshi/OneDrive/Documents/Playground/volcminer-server-migration/DEPLOY_UBUNTU_10.0.0.52.md)
