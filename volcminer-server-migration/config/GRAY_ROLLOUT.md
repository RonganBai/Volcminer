# Gray Rollout Template

Recommended rollout:

1. Start with `50` miners in one rack or one subnet.
2. Observe at least `4-8` scheduler cycles.
3. Expand to `100-200` miners only after CPU, memory, and scan delay behavior stay stable.

Files:

- `config/miners-gray-template.csv`: edit miner IP, credentials, rack, and tags.
- `config/miners-gray.generated.json`: generated output for deployment.
- `config/miners-discovered.csv`: auto-discovery scan report.
- `config/miners-discovered.generated.json`: auto-generated miner config from discovery.

Generate config:

```bash
npm run generate:gray
```

Or provide custom paths:

```bash
node tools/generateGrayConfig.mjs ./config/miners-gray-template.csv ./config/miners-gray.generated.json
```

Auto-discover a subnet with shared credentials:

```bash
npm run discover:subnet -- 172.100.1 1 255 root 'ltc@dog' 8 5
```

Arguments:

1. subnet prefix, such as `172.100.1`
2. start host, such as `1`
3. end host, such as `255`
4. username
5. password
6. concurrency, recommended `4-8`
7. timeout seconds per host

Discovery will:

- probe `get_system_infoV1.cgi` and `get_miner_statusV1.cgi`
- write a full CSV report for all IPs
- generate a JSON config where only the first `50` found miners are enabled by default

Enable the first `N` discovered miners:

```bash
npm run set:enabled -- ./config/miners-discovered.generated.json ./config/miners-discovered.generated.json 60
```

Examples:

- enable `60` miners for the next rollout step
- enable `200` miners after the first batch remains stable

Suggested CSV workflow:

- Keep `enabled=true` only for the first `50` miners.
- Leave the next `50-150` miners as `enabled=false` until the first batch is stable.
- Use tags like `gray|rack-a|batch-01` so the client can filter by rollout batch later.
- On the shared HashSentry server, prefer discovery concurrency `4-8`, not `50+`.
- Increase enabled count gradually: `50 -> 60 -> 100 -> 150 -> 200`.
