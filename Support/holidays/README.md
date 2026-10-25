# 节假日数据

`{year}.json` 为当年中国法定节假日安排，格式与 [holiday-cn](https://github.com/NateScarlet/holiday-cn) 兼容：

```json
{
  "year": 2026,
  "papers": ["https://www.gov.cn/..."],
  "days": [
    { "date": "2026-01-01", "name": "元旦", "isOffDay": true },
    { "date": "2026-01-04", "name": "元旦", "isOffDay": false }
  ]
}
```

- 原始来源：国务院办公厅《关于 {year} 年部分节假日安排的通知》
- 应用只使用 `isOffDay = true` 的放假日；周六日不参与周标记；调休补班日（`isOffDay = false`）忽略
- 每年 11–12 月发布次年安排后，运行 `make holidays YEAR=2027` 更新并重新打包
- 运行时 App 会自动抓取当前年/次年缺失的数据并缓存（校验失败则保留旧数据）
