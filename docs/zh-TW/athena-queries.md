# Athena VPC Flow Logs 常用查詢

使用 Athena workgroup `hermes-agent`，database `hermes_agent`。

## 過去一天出入站流量

```sql
SELECT flow_direction,
       action,
       COUNT(*) AS flow_count,
       SUM(bytes) AS total_bytes,
       SUM(packets) AS total_packets
FROM vpc_flow_logs
WHERE "start" > to_unixtime(now() - interval '1' day)
  AND log_status = 'OK'
GROUP BY flow_direction, action
ORDER BY total_bytes DESC;
```

## 內網流量 (VPC 內部)

```sql
SELECT srcaddr, dstaddr, srcport, dstport, protocol,
       SUM(bytes) AS total_bytes,
       SUM(packets) AS total_packets,
       COUNT(*) AS flow_count
FROM vpc_flow_logs
WHERE "start" > to_unixtime(now() - interval '1' day)
  AND log_status = 'OK'
  AND srcaddr LIKE '10.0.%'
  AND dstaddr LIKE '10.0.%'
GROUP BY srcaddr, dstaddr, srcport, dstport, protocol
ORDER BY total_bytes DESC
LIMIT 50;
```

## 外網流量

```sql
SELECT srcaddr, dstaddr, dstport, protocol, flow_direction,
       SUM(bytes) AS total_bytes,
       SUM(packets) AS total_packets,
       COUNT(*) AS flow_count
FROM vpc_flow_logs
WHERE "start" > to_unixtime(now() - interval '1' day)
  AND log_status = 'OK'
  AND NOT (srcaddr LIKE '10.0.%' AND dstaddr LIKE '10.0.%')
GROUP BY srcaddr, dstaddr, dstport, protocol, flow_direction
ORDER BY total_bytes DESC
LIMIT 50;
```

## Top Talkers (依流量排序)

```sql
SELECT srcaddr,
       dstaddr,
       SUM(bytes) AS total_bytes,
       SUM(packets) AS total_packets,
       COUNT(*) AS flow_count
FROM vpc_flow_logs
WHERE "start" > to_unixtime(now() - interval '1' day)
  AND log_status = 'OK'
GROUP BY srcaddr, dstaddr
ORDER BY total_bytes DESC
LIMIT 20;
```

## 被拒絕連線 Top 來源 IP (偵測掃描/攻擊)

```sql
SELECT
    srcaddr,
    dstport,
    COUNT(*) AS reject_count,
    SUM(packets) AS total_packets
FROM hermes_agent.vpc_flow_logs
WHERE action = 'REJECT'
    AND log_status = 'OK'
    AND start > to_unixtime(current_timestamp - interval '24' hour)
GROUP BY srcaddr, dstport
ORDER BY reject_count DESC
LIMIT 20;
```
