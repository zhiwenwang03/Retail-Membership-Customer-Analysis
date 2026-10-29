# 山姆用户消费数据集（模拟）

按飞书文档《山姆用户消费数据可视化分析》的表结构生成的模拟数据，用来从头到尾跑通该项目。数据是随机生成的，不是真实业务数据。

| 文件 | 行数 | 说明 |
|---|---|---|
| users.csv | 5,000 | 用户基础信息 |
| user_features.csv | 5,000 | 用户统计特征（由订单、行为聚合而来） |
| products.csv | 2,000 | 商品信息（14 个品类） |
| product_features.csv | 2,000 | 商品统计特征 |
| orders.csv | 15,000 | 订单，2025-10-01 ~ 2026-09-30 |
| user_behaviors.csv | 30,000 | 浏览 / 点击 / 收藏 / 加购 行为 |
| 00_建库建表并导入数据.sql | — | 一键建库 `sam_analysis`、建 6 张表并插入全部数据 |
| generate_data.py | — | 生成脚本，固定随机种子，重跑结果相同 |

## 导入 MySQL（8.0+）
在 Navicat / DBeaver / MySQL Workbench 里直接运行 `00_建库建表并导入数据.sql`，或者在命令行执行：

```
mysql -u root -p --default-character-set=utf8mb4 < 00_建库建表并导入数据.sql
```

之后从文档第一章开始执行 SQL 即可（`USE sam_analysis;`）。

## 刻意保留的数据特征（对应文档各章节）
- delivery_date / receive_date 为空：对应 待付款、已付款、已取消（以及已发货未收货）状态
- review_score / review_content 为空：未评价订单（只有已完成订单会有评价）
- 38 条异常订单：actual_payment = 0 的测试订单，以及 quantity = 0 的订单
- 部分小样本商品 conversion_rate = 1（文档 6.4 节）
- 各表外键 100% 匹配，主键无重复

## 文档 SQL 需要修正的地方
1. 2.4 节的改名方向反了（改完后 3.2 节会报错）。建议跳过 2.4，并把 6.4 节里的 `浏览_count` 换成 `view_count`
2. 3.4 节：`SELECT * cnt` 改为 `SELECT COUNT(*) cnt`
3. 6.4 节：`COUNT()` 改为 `COUNT(*)`
