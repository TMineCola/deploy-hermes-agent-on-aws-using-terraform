# Athena VPC Flow Logs Common Queries

Uses Athena workgroup `hermes-agent`, database `hermes_agent`.

## Inbound and Outbound Traffic in the Past Day

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

## Internal Traffic (Within VPC)

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

## External Traffic

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

## Top Talkers (Sorted by Traffic)

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

## Top Rejected Connection Source IPs (Detect Scanning/Attacks)

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
