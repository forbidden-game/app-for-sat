# Supabase 后端文档

日期：2026-01-06

## 目的
该目录用于记录当前 Supabase 后端的表结构、用途、字段与关系，作为后端结构的权威说明。

## 更新约定
- 任何对 `supabase/migrations/*.sql` 的修改，都必须在同一 PR 中同步更新 `schema.md`。
- 新增或删除表时，需更新 `schema.md` 中的总览与对应表描述。
- 新增或变更函数/RPC/视图时，需更新 `schema.md` 的相关章节。

## 文件
- `schema.md`：完整 schema 文档（表、字段、关系、视图、RPC）。
