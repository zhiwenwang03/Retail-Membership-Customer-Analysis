# -*- coding: utf-8 -*-
"""
山姆用户消费数据（模拟）生成脚本
按飞书文档《山姆用户消费数据可视化分析》中 6 张表的字段结构生成：
users / user_features / products / product_features / orders / user_behaviors
输出：6 个 CSV + 一个可直接在 MySQL 8.0 执行的建表导入脚本
运行：python generate_data.py
"""
import csv
import math
import os
import random
from collections import defaultdict
from datetime import date, datetime, timedelta

random.seed(2026)
OUT = os.path.dirname(os.path.abspath(__file__))

N_USERS, N_PRODUCTS, N_ORDERS, N_BEHAVIORS = 5000, 2000, 15000, 30000
ORDER_START, ORDER_END = date(2025, 10, 1), date(2026, 9, 30)


def rand_date(d0, d1):
    return d0 + timedelta(days=random.randint(0, (d1 - d0).days))


def wchoice(items, weights):
    return random.choices(items, weights=weights, k=1)[0]


# ---------------------------------------------------------------- users
PROVINCES = {
    "广东": (["广州", "深圳", "东莞", "佛山", "珠海"], 14), "江苏": (["南京", "苏州", "无锡", "常州"], 10),
    "浙江": (["杭州", "宁波", "温州", "绍兴"], 9), "上海": (["上海"], 8), "北京": (["北京"], 7),
    "山东": (["济南", "青岛", "烟台"], 6), "四川": (["成都", "绵阳"], 6), "福建": (["福州", "厦门", "泉州"], 5),
    "湖北": (["武汉", "宜昌"], 5), "河南": (["郑州", "洛阳"], 4), "湖南": (["长沙", "株洲"], 4),
    "天津": (["天津"], 3), "重庆": (["重庆"], 3), "安徽": (["合肥", "芜湖"], 3), "陕西": (["西安"], 3),
    "辽宁": (["沈阳", "大连"], 2), "江西": (["南昌"], 2), "云南": (["昆明"], 2), "广西": (["南宁", "桂林"], 2),
    "河北": (["石家庄", "保定"], 1), "山西": (["太原"], 1), "贵州": (["贵阳"], 1),
}
prov_names = list(PROVINCES)
prov_w = [PROVINCES[p][1] for p in prov_names]


def rand_age():
    # 25-44 岁为主力
    band = wchoice([(18, 24), (25, 34), (35, 44), (45, 54), (55, 65)], [20, 40, 30, 7, 3])
    return random.randint(*band)


users = []
user_activity = {}
for i in range(1, N_USERS + 1):
    uid = f"U{i:05d}"
    prov = wchoice(prov_names, prov_w)
    users.append({
        "user_id": uid,
        "age": rand_age(),
        "gender": wchoice(["女", "男"], [57, 43]),
        "province": prov,
        "city": random.choice(PROVINCES[prov][0]),
        "registration_date": rand_date(date(2021, 1, 1), date(2025, 9, 30)).isoformat(),
        "member_level": None,  # 订单生成后按消费分配
        "account_balance": round(min(random.lognormvariate(6.5, 1.2), 50000), 2),
        "credit_score": max(350, min(950, int(random.gauss(680, 80)))),
    })
    user_activity[uid] = random.lognormvariate(0, 1.0)

# ---------------------------------------------------------------- products
CATEGORIES = {
    # 品类: (品牌, 商品名, 价格区间, 销量权重)
    "生鲜果蔬": (["Member's Mark", "佳沛", "都乐", "百果园", "鲜丰"], ["智利车厘子", "新西兰奇异果", "有机蔬菜礼盒", "泰国榴莲", "海南芒果", "云南蓝莓"], (20, 300), 16),
    "肉禽水产": (["Member's Mark", "恒都", "国联", "獐子岛", "圣农"], ["澳洲牛排", "冷冻大虾", "三文鱼刺身", "鸡胸肉", "黑猪五花肉", "帝王蟹腿"], (40, 600), 13),
    "乳品烘焙": (["Member's Mark", "安佳", "蒙牛", "伊利", "君乐宝"], ["瑞士卷", "全脂牛奶", "希腊酸奶", "黄油牛角包", "芝士蛋糕", "麻薯"], (15, 150), 14),
    "零食饮料": (["Member's Mark", "三只松鼠", "良品铺子", "农夫山泉", "可口可乐"], ["每日坚果", "气泡水", "混合果干", "薯片大礼包", "椰子水", "牛肉干"], (10, 200), 14),
    "粮油调味": (["Member's Mark", "金龙鱼", "福临门", "海天", "李锦记"], ["五常大米", "橄榄油", "生抽酱油", "有机面粉", "火锅底料", "蚝油"], (15, 300), 8),
    "酒水": (["Member's Mark", "奔富", "茅台", "青岛啤酒", "轩尼诗"], ["红葡萄酒", "精酿啤酒", "白酒礼盒", "干邑白兰地", "气泡酒"], (50, 3000), 4),
    "美妆个护": (["欧莱雅", "雅诗兰黛", "兰蔻", "资生堂", "多芬"], ["精华液", "面霜", "洗发水套装", "防晒霜", "沐浴露", "护手霜"], (30, 1200), 7),
    "母婴用品": (["花王", "帮宝适", "惠氏", "美赞臣", "贝亲"], ["纸尿裤", "婴儿奶粉", "湿巾", "婴儿洗护套装", "奶瓶"], (50, 800), 5),
    "日用百货": (["Member's Mark", "维达", "清风", "蓝月亮", "汰渍"], ["抽纸", "洗衣液", "保鲜袋", "厨房纸", "垃圾袋", "洗洁精"], (10, 300), 9),
    "家居家纺": (["Member's Mark", "罗莱", "水星家纺", "富安娜", "乐扣乐扣"], ["四件套", "羽绒被", "收纳箱", "保温杯", "乳胶枕"], (50, 2000), 3),
    "家用电器": (["美的", "格力", "戴森", "飞利浦", "九阳"], ["空气炸锅", "吸尘器", "电饭煲", "空气净化器", "破壁机", "电动牙刷"], (200, 6000), 3),
    "数码产品": (["苹果", "华为", "小米", "索尼", "联想"], ["蓝牙耳机", "平板电脑", "智能手表", "充电宝", "笔记本电脑", "数据线"], (50, 9000), 2),
    "服饰鞋包": (["Member's Mark", "优衣库", "耐克", "阿迪达斯", "新秀丽"], ["羽绒服", "运动鞋", "行李箱", "纯棉T恤", "双肩包"], (50, 1500), 2),
    "营养保健": (["Swisse", "汤臣倍健", "Kirkland", "善存", "健合"], ["复合维生素", "鱼油", "钙片", "蛋白粉", "益生菌"], (80, 800), 4),
}
SPECS = ["", " 家庭装", " 礼盒装", " 量贩装", " 2件装", " 大包装", " 经典款", " 升级款"]

products = []
prod_pop = {}
for i in range(1, N_PRODUCTS + 1):
    pid = f"P{i:05d}"
    cat = wchoice(list(CATEGORIES), [math.sqrt(v[3]) for v in CATEGORIES.values()])
    brands, names, (lo, hi), cat_w = CATEGORIES[cat]
    # 区间内对数均匀分布，偏向低价
    price = math.exp(random.uniform(math.log(lo), math.log(hi)))
    price = round(price, 1) - 0.1 if price > 20 else round(price, 1)
    brand = random.choice(brands)
    products.append({
        "product_id": pid,
        "product_name": f"{brand} {random.choice(names)}{random.choice(SPECS)}",
        "category": cat,
        "brand": brand,
        "price": round(max(price, 1.9), 2),
        "sales_count": 0,
    })
    # 便宜 + 高频品类更容易被买，少数爆款
    prod_pop[pid] = cat_w * random.lognormvariate(0, 1.1) / (1 + math.log10(price))
prod_by_id = {p["product_id"]: p for p in products}

# ---------------------------------------------------------------- orders
uid_list = [u["user_id"] for u in users]
uid_w = [user_activity[u] for u in uid_list]
pid_list = [p["product_id"] for p in products]
pid_w = [prod_pop[p] for p in pid_list]

STATUS = ["待付款", "已付款", "已发货", "已完成", "已取消"]
STATUS_W = [5, 7, 10, 70, 8]
PAYMENTS = ["微信支付", "支付宝", "银行卡", "山姆储值卡"]
PAYMENT_W = [45, 30, 15, 10]
GOOD_REVIEWS = ["品质很好，会回购", "物流很快，包装完好", "性价比高，家里人都喜欢", "和描述一致，满意", "山姆的东西一如既往地好", "分量足，值这个价"]
MID_REVIEWS = ["还可以，一般般", "包装有点简陋", "价格略贵，品质还行", "物流稍慢"]
BAD_REVIEWS = ["质量不太好，有点失望", "收到有破损", "和图片差距较大", "不新鲜，体验差"]

reg_date = {u["user_id"]: date.fromisoformat(u["registration_date"]) for u in users}
orders = []
for i in range(1, N_ORDERS + 1):
    uid = random.choices(uid_list, uid_w)[0]
    pid = random.choices(pid_list, pid_w)[0]
    price = prod_by_id[pid]["price"]
    qty = wchoice([1, 2, 3, 4, 5], [55, 25, 10, 6, 4]) if price < 500 else wchoice([1, 2], [92, 8])
    unit_price = price
    total = round(qty * unit_price, 2)
    discount = round(total * wchoice([0, 0.05, 0.1, 0.15, 0.2], [45, 20, 20, 10, 5]), 2)
    od = rand_date(max(ORDER_START, reg_date[uid]), ORDER_END)
    status = wchoice(STATUS, STATUS_W)
    order_dt = datetime.combine(od, datetime.min.time()) + timedelta(seconds=random.randint(8 * 3600, 23 * 3600))
    delivery = receive = None
    if status in ("已发货", "已完成"):
        delivery = od + timedelta(days=random.randint(0, 2))
        if status == "已完成":
            receive = delivery + timedelta(days=random.randint(1, 4))
    score = content = None
    if status == "已完成" and random.random() < 0.72:
        score = wchoice([5, 4, 3, 2, 1], [55, 25, 10, 6, 4])
        content = random.choice(GOOD_REVIEWS if score >= 4 else MID_REVIEWS if score == 3 else BAD_REVIEWS)
    orders.append({
        "order_id": f"O{i:06d}", "user_id": uid, "product_id": pid, "quantity": qty,
        "order_date": order_dt.strftime("%Y-%m-%d %H:%M:%S"), "order_status": status,
        "payment_method": wchoice(PAYMENTS, PAYMENT_W), "unit_price": unit_price,
        "total_amount": total, "discount": discount, "actual_payment": round(total - discount, 2),
        "delivery_date": delivery.isoformat() if delivery else None,
        "receive_date": receive.isoformat() if receive else None,
        "review_score": score, "review_content": content,
    })

# 少量异常记录（文档 2.2：actual_payment=0 的测试订单、数量为 0 的记录）
for o in random.sample(orders, 30):
    o["discount"] = o["total_amount"]
    o["actual_payment"] = 0.0
for o in random.sample(orders, 8):
    o["quantity"] = 0
    o["total_amount"] = o["discount"] = o["actual_payment"] = 0.0

# ---------------------------------------------------------------- user_behaviors
BEHAVIOR_TYPES = ["浏览", "点击", "收藏", "加购"]
BEHAVIOR_W = [65, 18, 8, 9]
behaviors = []
t0 = datetime.combine(ORDER_START, datetime.min.time())
span = int((datetime.combine(ORDER_END, datetime.max.time()) - t0).total_seconds())
for i in range(1, N_BEHAVIORS + 1):
    btype = wchoice(BEHAVIOR_TYPES, BEHAVIOR_W)
    ts = t0 + timedelta(seconds=random.randint(0, span))
    # 白天、晚间更活跃
    ts = ts.replace(hour=wchoice(list(range(24)), [1, 1, 1, 1, 1, 1, 2, 3, 4, 5, 5, 6, 7, 6, 5, 5, 5, 6, 7, 9, 10, 9, 6, 3]))
    behaviors.append({
        "behavior_id": f"B{i:06d}",
        "user_id": random.choices(uid_list, uid_w)[0],
        "product_id": random.choices(pid_list, pid_w)[0],
        "behavior_type": btype,
        "behavior_time": ts.strftime("%Y-%m-%d %H:%M:%S"),
        "duration_seconds": random.randint(5, 300) if btype == "浏览" else random.randint(1, 60),
    })
behaviors.sort(key=lambda b: b["behavior_time"])
for i, b in enumerate(behaviors, 1):
    b["behavior_id"] = f"B{i:06d}"

# ---------------------------------------------------------------- 聚合：user_features
VALID = {"已付款", "已发货", "已完成"}
u_spent, u_cnt, u_done = defaultdict(float), defaultdict(int), defaultdict(int)
p_rev, p_sales, p_done, p_cancel = defaultdict(float), defaultdict(int), defaultdict(int), defaultdict(int)
p_scores = defaultdict(list)
for o in orders:
    u_cnt[o["user_id"]] += 1
    if o["order_status"] in VALID:
        u_spent[o["user_id"]] += o["actual_payment"]
        p_rev[o["product_id"]] += o["actual_payment"]
        p_sales[o["product_id"]] += o["quantity"]
    if o["order_status"] == "已完成":
        u_done[o["user_id"]] += 1
        p_done[o["product_id"]] += 1
    if o["order_status"] == "已取消":
        p_cancel[o["product_id"]] += 1
    if o["review_score"]:
        p_scores[o["product_id"]].append(o["review_score"])

u_beh = defaultdict(lambda: defaultdict(int))
p_beh = defaultdict(lambda: defaultdict(int))
for b in behaviors:
    u_beh[b["user_id"]][b["behavior_type"]] += 1
    p_beh[b["product_id"]][b["behavior_type"]] += 1

# 会员等级：与消费正相关但带噪声
LEVELS = ["普通会员", "铜牌会员", "银牌会员", "金牌会员", "钻石会员"]
ranked = sorted(uid_list, key=lambda u: u_spent[u] * random.uniform(0.5, 1.5))
cut = [0.60, 0.72, 0.84, 0.94, 1.0]
for idx, uid in enumerate(ranked):
    q = (idx + 1) / len(ranked)
    lvl = next(LEVELS[k] for k, c in enumerate(cut) if q <= c)
    users[int(uid[1:]) - 1]["member_level"] = lvl

spent_sorted = sorted(u_spent[u] for u in uid_list)
low_cut = spent_sorted[int(len(spent_sorted) * 0.40)]
mid_cut = spent_sorted[int(len(spent_sorted) * 0.75)]
user_features = []
for u in users:
    uid = u["user_id"]
    s = round(u_spent[uid], 2)
    user_features.append({
        "user_id": uid, "total_spent": s, "order_count": u_cnt[uid], "completed_orders": u_done[uid],
        "avg_order_amount": round(s / u_cnt[uid], 2) if u_cnt[uid] else 0.0,
        "browse_count": u_beh[uid]["浏览"], "click_count": u_beh[uid]["点击"],
        "favorite_count": u_beh[uid]["收藏"], "cart_count": u_beh[uid]["加购"],
        "consumption_level": "低" if s <= low_cut else "中" if s <= mid_cut else "高",
        "member_level_score": LEVELS.index(u["member_level"]) + 1,
    })

# ---------------------------------------------------------------- 聚合：product_features
product_features = []
for p in products:
    pid = p["product_id"]
    sales = p_sales[pid]
    views = p_beh[pid]["浏览"]
    # 特征表统计口径为全量日志，浏览量大于行为抽样表；少数小样本商品转化率会出现 100%
    if sales and random.random() < 0.04:
        view_count = max(sales, views)
    elif sales:
        view_count = max(views, round(sales / random.uniform(0.04, 0.18)))
    else:
        view_count = views + random.randint(0, 30)
    click_count = max(p_beh[pid]["点击"], round(view_count * random.uniform(0.2, 0.35)))
    scores = p_scores[pid]
    product_features.append({
        "product_id": pid, "total_revenue": round(p_rev[pid], 2), "total_sales": sales,
        "completed_count": p_done[pid], "cancel_count": p_cancel[pid],
        "add_to_cart_count": max(p_beh[pid]["加购"], round(click_count * random.uniform(0.1, 0.25))),
        "favorite_count": max(p_beh[pid]["收藏"], round(click_count * random.uniform(0.08, 0.2))),
        "view_count": view_count, "click_count": click_count,
        "conversion_rate": round(min(1.0, sales / view_count), 4) if view_count else 0.0,
        "avg_review_score": round(sum(scores) / len(scores), 2) if scores else 0.0,
        "popularity_score": 0.0,
    })
    p["sales_count"] = sales + random.randint(0, 200)
max_pop = max(pf["view_count"] * 0.4 + pf["total_sales"] * 6 for pf in product_features) or 1
for pf in product_features:
    pf["popularity_score"] = round((pf["view_count"] * 0.4 + pf["total_sales"] * 6) / max_pop * 100, 2)

# ---------------------------------------------------------------- 输出
TABLES = [
    ("users", users, """
  user_id VARCHAR(10) PRIMARY KEY, age INT, gender VARCHAR(4), province VARCHAR(20), city VARCHAR(20),
  registration_date DATE, member_level VARCHAR(10), account_balance DECIMAL(12,2), credit_score INT"""),
    ("user_features", user_features, """
  user_id VARCHAR(10) PRIMARY KEY, total_spent DECIMAL(14,2), order_count INT, completed_orders INT,
  avg_order_amount DECIMAL(12,2), browse_count INT, click_count INT, favorite_count INT, cart_count INT,
  consumption_level VARCHAR(4), member_level_score INT"""),
    ("products", products, """
  product_id VARCHAR(10) PRIMARY KEY, product_name VARCHAR(100), category VARCHAR(20), brand VARCHAR(30),
  price DECIMAL(10,2), sales_count INT"""),
    ("product_features", product_features, """
  product_id VARCHAR(10) PRIMARY KEY, total_revenue DECIMAL(14,2), total_sales INT, completed_count INT,
  cancel_count INT, add_to_cart_count INT, favorite_count INT, view_count INT, click_count INT,
  conversion_rate DECIMAL(6,4), avg_review_score DECIMAL(4,2), popularity_score DECIMAL(6,2)"""),
    ("orders", orders, """
  order_id VARCHAR(10) PRIMARY KEY, user_id VARCHAR(10), product_id VARCHAR(10), quantity INT,
  order_date DATETIME, order_status VARCHAR(10), payment_method VARCHAR(10), unit_price DECIMAL(10,2),
  total_amount DECIMAL(12,2), discount DECIMAL(12,2), actual_payment DECIMAL(12,2),
  delivery_date DATE NULL, receive_date DATE NULL, review_score INT NULL, review_content VARCHAR(200) NULL"""),
    ("user_behaviors", behaviors, """
  behavior_id VARCHAR(10) PRIMARY KEY, user_id VARCHAR(10), product_id VARCHAR(10), behavior_type VARCHAR(10),
  behavior_time DATETIME, duration_seconds INT"""),
]


def sql_val(v):
    if v is None:
        return "NULL"
    if isinstance(v, (int, float)):
        return str(v)
    return "'" + str(v).replace("\\", "\\\\").replace("'", "''") + "'"


for name, rows, _ in TABLES:
    with open(os.path.join(OUT, f"{name}.csv"), "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        for r in rows:
            w.writerow({k: ("" if v is None else v) for k, v in r.items()})

with open(os.path.join(OUT, "00_建库建表并导入数据.sql"), "w", encoding="utf-8") as f:
    f.write("-- 山姆用户消费数据（模拟）  MySQL 8.0+\n")
    f.write("CREATE DATABASE IF NOT EXISTS sam_analysis DEFAULT CHARSET utf8mb4;\nUSE sam_analysis;\nSET NAMES utf8mb4;\n\n")
    for name, rows, ddl in TABLES:
        cols = list(rows[0])
        f.write(f"DROP TABLE IF EXISTS {name};\nCREATE TABLE {name} ({ddl}\n) DEFAULT CHARSET=utf8mb4;\n")
        for s in range(0, len(rows), 1000):
            f.write(f"INSERT INTO {name} ({', '.join(cols)}) VALUES\n")
            f.write(",\n".join("(" + ", ".join(sql_val(r[c]) for c in cols) + ")" for r in rows[s:s + 1000]))
            f.write(";\n")
        f.write("\n")

for name, rows, _ in TABLES:
    print(f"{name:18s} {len(rows):>6} 行")
