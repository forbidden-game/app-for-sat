# SAT Prep App - Test Framework

Version: 1.0  
Date: 2026-01-06  
Status: Approved

---

## 目录

1. [概述](#1-概述)
2. [测试分层架构](#2-测试分层架构)
3. [各层详细设计](#3-各层详细设计)
4. [测试数据策略](#4-测试数据策略)
5. [RLS 策略测试](#5-rls-策略测试)
6. [CI/CD 配置](#6-cicd-配置)
7. [开发者工作流](#7-开发者工作流)
8. [文件结构](#8-文件结构)
9. [实施路线图](#9-实施路线图)
10. [维护指南](#10-维护指南)

---

## 1. 概述

### 1.1 项目技术栈

| 层级    | 技术                                | 测试工具           |
| ------- | ----------------------------------- | ------------------ |
| iOS     | Swift 6.2 / SwiftUI                 | XCTest             |
| Web     | Next.js 16 / React 19 / TypeScript  | Vitest             |
| Backend | Supabase (Postgres, Edge Functions) | Vitest + Deno Test |
| E2E     | 跨层验收                            | Playwright         |

### 1.2 核心原则

1. **RLS/RPC 是应用逻辑** — 测试的主要目的是证明用户不能访问或修改不该碰的数据
2. **真实依赖优于 Mock** — 核心逻辑在 DB 层，Mock 会漏掉 policy bugs
3. **测试隔离** — 每个测试独立，可并行运行
4. **快速反馈** — 本地测试 < 30s，CI 全量 < 5min

### 1.3 覆盖率目标

| 层级        | 目标            | 说明                            |
| ----------- | --------------- | ------------------------------- |
| Unit        | 80%+            | 工具函数全覆盖                  |
| Integration | 核心路径 100%   | 每个 Server Action 至少一个测试 |
| RLS         | 角色 × 操作矩阵 | 关键表的权限验证                |
| E2E         | 关键路径        | 不追求覆盖率，只保护核心流程    |

---

## 2. 测试分层架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    测试金字塔                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│            /\                                                   │
│           /  \       E2E: 5-10 tests                           │
│          / E2E\      - 关键用户路径                              │
│         /      \     - "用户会因此流失"的场景                     │
│        /--------\                                               │
│       /          \   Integration: 30-50 tests                  │
│      /Integration \  - Server Actions + DB                     │
│     /              \ - RLS 策略验证                              │
│    /----------------\                                           │
│   /                  \ Unit: 20-30 tests                       │
│  /       Unit         \- 纯函数、工具方法                        │
│ /                      \- 验证逻辑                               │
│/________________________\                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 各层职责

| 层级            | 测什么                   | 不测什么     | 运行时机       |
| --------------- | ------------------------ | ------------ | -------------- |
| **Unit**        | 格式化、验证、计算逻辑   | DB、网络、UI | 每次保存       |
| **Integration** | Server Actions、RPC、RLS | UI 渲染      | 每次 commit    |
| **E2E**         | 完整用户流程             | 边缘情况     | PR 合并到 main |

---

## 3. 各层详细设计

### 3.1 Unit Tests

**工具**: Vitest (Web) / XCTest (iOS)

**范围**: 无副作用的纯函数

**文件位置**: 与源文件同目录

```
web/admin-dashboard/src/lib/
├── format.ts
├── format.test.ts         # Unit test
├── validation.ts
└── validation.test.ts     # Unit test
```

**示例**:

```typescript
// validation.ts
export function validateQuestionStem(stem: string): string | null {
  if (!stem.trim()) return "题干不能为空";
  if (stem.length > 5000) return "题干不能超过5000字符";
  return null;
}

export function validateAnswerKey(questionType: string, answerKey: unknown): string | null {
  if (questionType === "mcq") {
    if (typeof answerKey !== "object" || !answerKey) return "答案格式错误";
    const key = answerKey as Record<string, unknown>;
    if (typeof key.correct !== "string") return "MCQ 答案必须是字母";
    if (!/^[A-Z]$/.test(key.correct)) return "答案必须是单个大写字母";
  }
  return null;
}

// validation.test.ts
import { describe, it, expect } from "vitest";
import { validateQuestionStem, validateAnswerKey } from "./validation";

describe("validateQuestionStem", () => {
  it("rejects empty stem", () => {
    expect(validateQuestionStem("")).toBe("题干不能为空");
    expect(validateQuestionStem("   ")).toBe("题干不能为空");
  });

  it("accepts valid stem", () => {
    expect(validateQuestionStem("What is 2+2?")).toBeNull();
  });

  it("rejects stem over 5000 chars", () => {
    const longStem = "a".repeat(5001);
    expect(validateQuestionStem(longStem)).toBe("题干不能超过5000字符");
  });
});

describe("validateAnswerKey", () => {
  it("validates MCQ answer format", () => {
    expect(validateAnswerKey("mcq", { correct: "A" })).toBeNull();
    expect(validateAnswerKey("mcq", { correct: "AB" })).toBe("答案必须是单个大写字母");
    expect(validateAnswerKey("mcq", { correct: 1 })).toBe("MCQ 答案必须是字母");
  });
});
```

**运行命令**:

```bash
# Web
cd web/admin-dashboard
npm run test:unit           # 运行所有 unit tests
npm run test:unit -- --watch # Watch 模式

# iOS
swift test --package-path ios/StudentCore --filter "Unit"
```

---

### 3.2 Integration Tests

**工具**: Vitest + Real Supabase Local

**范围**: Server Actions 与数据库的交互

**关键决策**: 使用真实 Supabase Local（非 Mock）

**理由**:

- 核心逻辑在 RLS/RPC 层，Mock 会漏掉 policy bugs
- Supabase Local 启动快（~10s）
- 测试真实 SQL 行为

**文件位置**: `__tests__/` 子目录

```
web/admin-dashboard/src/app/(admin)/admin/
├── questions/
│   ├── actions.ts
│   └── __tests__/
│       └── actions.test.ts    # Integration test
├── tags/
│   ├── actions.ts
│   └── __tests__/
│       └── actions.test.ts
```

**示例**:

```typescript
// questions/__tests__/actions.test.ts
import { describe, it, expect, beforeAll, afterEach } from "vitest";
import { createQuestion, updateQuestion, deleteQuestion, listQuestions } from "../actions";
import { withTransaction, createTestAdmin } from "@/test/helpers";
import { questionFactory } from "@/test/fixtures/questions";

describe("Questions CRUD", () => {
  beforeAll(async () => {
    await createTestAdmin();
  });

  describe("createQuestion", () => {
    it("creates MCQ question with options", async () => {
      await withTransaction(async () => {
        const input = questionFactory.mcq({
          stem: "What is 2+2?",
          options: [
            { label: "A", content: "3" },
            { label: "B", content: "4" },
            { label: "C", content: "5" },
            { label: "D", content: "6" },
          ],
          answer_key: { correct: "B" },
        });

        const result = await createQuestion(input);

        expect(result.id).toBeDefined();
        expect(result.stem).toBe("What is 2+2?");
        expect(result.question_type).toBe("mcq");
      });
    });

    it("creates numeric question", async () => {
      await withTransaction(async () => {
        const input = questionFactory.numeric({
          stem: "Calculate: 15 * 3 = ?",
          answer_key: { correct: 45 },
        });

        const result = await createQuestion(input);

        expect(result.question_type).toBe("numeric");
        expect(result.answer_key).toEqual({ correct: 45 });
      });
    });

    it("rejects question without stem", async () => {
      await withTransaction(async () => {
        const input = questionFactory.mcq({ stem: "" });
        await expect(createQuestion(input)).rejects.toThrow();
      });
    });
  });

  describe("listQuestions", () => {
    it("filters by subject", async () => {
      await withTransaction(async () => {
        // Setup: create questions with different subjects
        await createQuestion(questionFactory.mcq({ subject: "Math" }));
        await createQuestion(questionFactory.mcq({ subject: "English" }));

        const result = await listQuestions({ subject: "Math", page: 1 });

        expect(result.questions.every((q) => q.subject === "Math")).toBe(true);
      });
    });

    it("paginates correctly", async () => {
      await withTransaction(async () => {
        // Setup: create 10 questions
        for (let i = 0; i < 10; i++) {
          await createQuestion(questionFactory.mcq());
        }

        const page1 = await listQuestions({ page: 1, pageSize: 5 });
        const page2 = await listQuestions({ page: 2, pageSize: 5 });

        expect(page1.questions.length).toBe(5);
        expect(page2.questions.length).toBe(5);
        expect(page1.questions[0].id).not.toBe(page2.questions[0].id);
      });
    });

    it("searches by stem content", async () => {
      await withTransaction(async () => {
        await createQuestion(questionFactory.mcq({ stem: "Find the value of x" }));
        await createQuestion(questionFactory.mcq({ stem: "Calculate the sum" }));

        const result = await listQuestions({ search: "value", page: 1 });

        expect(result.questions.length).toBe(1);
        expect(result.questions[0].stem).toContain("value");
      });
    });
  });
});
```

**运行命令**:

```bash
# 需要先启动 Supabase Local
supabase start

# 运行 Integration Tests
cd web/admin-dashboard
npm run test:integration

# 运行单个文件
npm run test:integration -- questions/__tests__/actions.test.ts
```

---

### 3.3 RLS 策略测试

**目的**: 验证 Row Level Security 策略正确性

**关键**: 这是安全边界，必须覆盖

**测试矩阵**:

| 表        | student     | parent        | admin   |
| --------- | ----------- | ------------- | ------- |
| questions | ❌ 不可读   | ❌ 不可读     | ✅ CRUD |
| attempts  | ✅ 只读自己 | ✅ 读关联学生 | ✅ 全部 |
| sessions  | ✅ 只读自己 | ✅ 读关联学生 | ✅ 全部 |
| profiles  | ✅ 只读自己 | ✅ 读关联     | ✅ 全部 |

**文件位置**: `test/rls/`

```
web/admin-dashboard/test/
└── rls/
    ├── questions.test.ts
    ├── attempts.test.ts
    └── sessions.test.ts
```

**示例**:

```typescript
// test/rls/questions.test.ts
import { describe, it, expect, beforeAll } from "vitest";
import { createClientAs } from "@/test/helpers";

describe("Questions RLS", () => {
  describe("student role", () => {
    it("cannot read questions table directly", async () => {
      const client = await createClientAs("student");
      const { data, error } = await client.from("questions").select("*");

      // RLS should return empty array, not error
      expect(error).toBeNull();
      expect(data).toEqual([]);
    });

    it("cannot insert questions", async () => {
      const client = await createClientAs("student");
      const { error } = await client.from("questions").insert({
        stem: "Hacked question",
        subject: "Math",
        module: "Algebra",
        difficulty: 1,
        question_type: "mcq",
        answer_key: { correct: "A" },
      });

      expect(error).not.toBeNull();
    });
  });

  describe("admin role", () => {
    it("can read all questions", async () => {
      const client = await createClientAs("admin");
      const { data, error } = await client.from("questions").select("*");

      expect(error).toBeNull();
      expect(data?.length).toBeGreaterThan(0);
    });

    it("can create questions", async () => {
      const client = await createClientAs("admin");
      const { data, error } = await client
        .from("questions")
        .insert({
          stem: "Admin created question",
          subject: "Math",
          module: "Algebra",
          difficulty: 1,
          question_type: "mcq",
          answer_key: { correct: "A" },
        })
        .select()
        .single();

      expect(error).toBeNull();
      expect(data?.stem).toBe("Admin created question");
    });
  });
});

// test/rls/attempts.test.ts
describe("Attempts RLS", () => {
  describe("student role", () => {
    it("can only read own attempts", async () => {
      const student1 = await createClientAs("student", "student1@test.com");
      const student2 = await createClientAs("student", "student2@test.com");

      // Student1 creates an attempt (via submit_attempt edge function)
      // ...

      // Student2 cannot see Student1's attempts
      const { data } = await student2.from("attempts").select("*");
      const otherStudentAttempts = data?.filter((a) => a.student_id !== student2.userId);
      expect(otherStudentAttempts).toEqual([]);
    });
  });

  describe("parent role", () => {
    it("can read linked student attempts", async () => {
      const parent = await createClientAs("parent");
      // Assuming parent is linked to a student
      const { data, error } = await parent.from("attempts").select("*");

      expect(error).toBeNull();
      // Should see linked student's attempts
    });

    it("cannot read unlinked student attempts", async () => {
      const parent = await createClientAs("parent");
      const { data } = await parent.from("attempts").select("*");

      // Should not see attempts from students not linked to this parent
      const unlinkedAttempts = data?.filter((a) => !parent.linkedStudentIds.includes(a.student_id));
      expect(unlinkedAttempts).toEqual([]);
    });
  });
});
```

**运行命令**:

```bash
npm run test:rls
# 或
npm run test:integration -- test/rls/
```

---

### 3.4 Edge Functions Tests

**工具**: Deno Test

**范围**: Edge Function 的核心逻辑

**文件位置**: 与 Edge Function 同目录

```
supabase/functions/
├── _shared/
│   ├── scoring.ts
│   └── scoring_test.ts        # ✅ 已有
├── submit_attempt/
│   └── index.ts
└── sign-asset-upload/
    ├── index.ts
    └── index_test.ts          # 新增
```

**示例**:

```typescript
// supabase/functions/sign-asset-upload/index_test.ts
import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("sign-asset-upload validates content type", async () => {
  // Test that only allowed image types are accepted
  const allowedTypes = ["image/png", "image/jpeg", "image/gif", "image/webp"];

  for (const type of allowedTypes) {
    // Should not throw for valid types
    // ... test logic
  }
});

Deno.test("sign-asset-upload rejects invalid content types", async () => {
  const invalidTypes = ["application/pdf", "text/plain", "video/mp4"];

  for (const type of invalidTypes) {
    // Should throw/reject for invalid types
    // ... test logic
  }
});

Deno.test("sign-asset-upload requires admin role", async () => {
  // Test that non-admin users are rejected
  // ... test logic
});
```

**运行命令**:

```bash
deno test --allow-read --allow-env supabase/functions/
```

---

### 3.5 E2E Tests

**工具**: Playwright

**范围**: 关键用户路径（"用户会因此流失"的场景）

**必须覆盖的场景**:

| #   | 场景                  | 理由              |
| --- | --------------------- | ----------------- |
| 1   | Admin 登录            | 进不去 = 无法管理 |
| 2   | 创建 MCQ 题目完整流程 | 核心功能          |
| 3   | 批量导入题目          | 效率功能          |
| 4   | 题库编排（排序）      | 内容管理          |
| 5   | 学生答题流程          | 核心产品价值      |
| 6   | 错误处理（网络错误）  | 优雅降级          |

**文件结构**:

```
web/admin-dashboard/
├── e2e/
│   ├── fixtures/
│   │   ├── test-import.json
│   │   └── test-image.png
│   ├── auth.setup.ts           # 登录状态复用
│   ├── admin-login.spec.ts
│   ├── question-crud.spec.ts
│   ├── question-import.spec.ts
│   └── bank-questions.spec.ts
└── playwright.config.ts
```

**登录状态复用**:

```typescript
// e2e/auth.setup.ts
import { test as setup, expect } from "@playwright/test";

setup("authenticate as admin", async ({ page }) => {
  await page.goto("/login");
  await page.fill('[name="email"]', process.env.TEST_ADMIN_EMAIL!);
  await page.fill('[name="password"]', process.env.TEST_ADMIN_PASSWORD!);
  await page.click('button[type="submit"]');

  // 等待登录完成
  await expect(page).toHaveURL(/\/admin/);

  // 保存登录状态供其他测试复用
  await page.context().storageState({ path: ".auth/admin.json" });
});
```

**E2E 测试示例**:

```typescript
// e2e/question-crud.spec.ts
import { test, expect } from "@playwright/test";

test.describe("Question CRUD", () => {
  test.use({ storageState: ".auth/admin.json" });

  test("admin can create MCQ question with options", async ({ page }) => {
    // Navigate to create page
    await page.goto("/admin/questions/new");

    // Fill form
    await page.fill('[name="stem"]', "What is the capital of France?");
    await page.selectOption('[name="subject"]', "English");
    await page.selectOption('[name="question_type"]', "mcq");
    await page.selectOption('[name="difficulty"]', "2");

    // Add options
    await page.fill('[name="options.0.label"]', "A");
    await page.fill('[name="options.0.content"]', "London");
    await page.fill('[name="options.1.label"]', "B");
    await page.fill('[name="options.1.content"]', "Paris");
    await page.fill('[name="options.2.label"]', "C");
    await page.fill('[name="options.2.content"]', "Berlin");
    await page.fill('[name="options.3.label"]', "D");
    await page.fill('[name="options.3.content"]', "Madrid");

    // Set correct answer
    await page.fill('[name="correct_answer"]', "B");

    // Submit
    await page.click('button[type="submit"]');

    // Verify redirect to list
    await expect(page).toHaveURL("/admin/questions");

    // Verify question appears in list
    await expect(page.locator("text=What is the capital of France?")).toBeVisible();
  });

  test("admin can edit existing question", async ({ page }) => {
    // Navigate to questions list
    await page.goto("/admin/questions");

    // Click first question
    await page.click("table tbody tr:first-child a");

    // Edit stem
    const stemInput = page.locator('[name="stem"]');
    await stemInput.clear();
    await stemInput.fill("Updated question stem");

    // Save
    await page.click('button[type="submit"]');

    // Verify success
    await expect(page.locator("text=Updated question stem")).toBeVisible();
  });

  test("admin can delete question", async ({ page }) => {
    await page.goto("/admin/questions");

    // Get initial count
    const initialCount = await page.locator("table tbody tr").count();

    // Delete first question
    await page.click("table tbody tr:first-child button.delete");
    await page.click("button.confirm-delete");

    // Verify count decreased
    await expect(page.locator("table tbody tr")).toHaveCount(initialCount - 1);
  });
});

// e2e/question-import.spec.ts
test.describe("Question Import", () => {
  test.use({ storageState: ".auth/admin.json" });

  test("admin can bulk import questions from JSON", async ({ page }) => {
    await page.goto("/admin/questions/import");

    // Upload JSON file
    const fileInput = page.locator('input[type="file"]');
    await fileInput.setInputFiles("e2e/fixtures/test-import.json");

    // Submit import
    await page.click("button.import-submit");

    // Verify success message
    await expect(page.locator("text=成功导入")).toBeVisible();
    await expect(page.locator(".success-count")).toContainText("3"); // 3 questions imported
  });
});
```

**Playwright 配置**:

```typescript
// playwright.config.ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",

  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },

  projects: [
    // Setup project for authentication
    { name: "setup", testMatch: /.*\.setup\.ts/ },

    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
      dependencies: ["setup"],
    },
  ],

  // Start dev server before tests
  webServer: {
    command: "npm run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
  },
});
```

**运行命令**:

```bash
# 运行所有 E2E 测试
npx playwright test

# UI 模式（调试）
npx playwright test --ui

# 只运行特定文件
npx playwright test question-crud.spec.ts

# 生成测试报告
npx playwright show-report
```

---

### 3.6 iOS Tests

**工具**: XCTest

**现有结构**:

```
ios/StudentCore/
├── Sources/StudentCore/
│   ├── ViewModels/
│   │   └── QuestionFeedViewModel.swift
│   └── Services/
│       └── APIClient.swift
└── Tests/StudentCoreTests/
    ├── QuestionFeedViewModelTests.swift  # ✅ 已有
    ├── Mocks/
    │   └── MockAPIClient.swift           # ✅ 已有
    └── ...
```

**运行命令**:

```bash
# 运行所有测试
swift test --package-path ios/StudentCore

# 运行特定测试
swift test --package-path ios/StudentCore --filter QuestionFeedViewModelTests
```

---

## 4. 测试数据策略

### 4.1 核心原则

1. **测试隔离**: 每个测试独立，不依赖其他测试的数据
2. **事务回滚**: Integration Tests 使用事务包裹，测试后自动回滚
3. **工厂函数**: 统一的测试数据创建方式，避免复制粘贴
4. **唯一标识**: 使用时间戳/UUID 前缀避免冲突

### 4.2 事务回滚机制

```sql
-- supabase/migrations/YYYYMMDDHHMM_test_helpers.sql (仅用于测试环境)
-- 或者通过 seed.sql 添加

-- 开始测试事务
create or replace function begin_test_transaction()
returns void as $$
begin
  -- 创建 savepoint
  execute 'savepoint test_savepoint';
end;
$$ language plpgsql;

-- 回滚测试事务
create or replace function rollback_test_transaction()
returns void as $$
begin
  -- 回滚到 savepoint
  execute 'rollback to savepoint test_savepoint';
end;
$$ language plpgsql;
```

```typescript
// test/helpers.ts
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!, // 使用 service role 进行测试
);

export async function withTransaction<T>(fn: () => Promise<T>): Promise<T> {
  await supabase.rpc("begin_test_transaction");
  try {
    return await fn();
  } finally {
    await supabase.rpc("rollback_test_transaction");
  }
}
```

### 4.3 测试数据工厂

```typescript
// test/fixtures/questions.ts
let counter = 0;

export const questionFactory = {
  mcq: (overrides: Partial<QuestionInput> = {}) => ({
    subject: "Math",
    module: "Algebra",
    difficulty: 3,
    question_type: "mcq",
    stem: `Test MCQ Question ${Date.now()}_${counter++}`,
    answer_key: { correct: "A" },
    options: [
      { label: "A", content: "Option A" },
      { label: "B", content: "Option B" },
      { label: "C", content: "Option C" },
      { label: "D", content: "Option D" },
    ],
    ...overrides,
  }),

  numeric: (overrides: Partial<QuestionInput> = {}) => ({
    subject: "Math",
    module: "Arithmetic",
    difficulty: 2,
    question_type: "numeric",
    stem: `Test Numeric Question ${Date.now()}_${counter++}`,
    answer_key: { correct: 42 },
    ...overrides,
  }),
};

// test/fixtures/users.ts
export const userFactory = {
  admin: (overrides = {}) => ({
    email: `admin_${Date.now()}@test.com`,
    password: "testpassword123",
    role: "admin",
    ...overrides,
  }),

  student: (overrides = {}) => ({
    email: `student_${Date.now()}@test.com`,
    password: "testpassword123",
    role: "student",
    ...overrides,
  }),

  parent: (overrides = {}) => ({
    email: `parent_${Date.now()}@test.com`,
    password: "testpassword123",
    role: "parent",
    ...overrides,
  }),
};

// test/fixtures/tags.ts
export const tagFactory = {
  create: (overrides = {}) => ({
    name: `tag_${Date.now()}_${counter++}`,
    category: "topic",
    ...overrides,
  }),
};
```

### 4.4 测试用户创建

```typescript
// test/helpers.ts
import { createClient } from "@supabase/supabase-js";

const serviceClient = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

// 创建测试用户并返回已认证的 client
export async function createClientAs(
  role: "admin" | "student" | "parent",
  email?: string,
): Promise<SupabaseClient & { userId: string }> {
  const testEmail = email || `${role}_${Date.now()}@test.com`;
  const testPassword = "testpassword123";

  // 创建用户
  const { data: authData, error: authError } = await serviceClient.auth.admin.createUser({
    email: testEmail,
    password: testPassword,
    email_confirm: true,
  });

  if (authError) throw authError;

  // 设置角色
  await serviceClient.from("profiles").update({ role }).eq("id", authData.user.id);

  // 创建用户级别的 client
  const userClient = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );

  await userClient.auth.signInWithPassword({
    email: testEmail,
    password: testPassword,
  });

  return Object.assign(userClient, { userId: authData.user.id });
}

// 创建持久化的测试 admin（用于 CI）
export async function createTestAdmin(): Promise<void> {
  const email = "admin@test.com";
  const password = "admin123456";

  // 检查是否已存在
  const { data: existing } = await serviceClient
    .from("profiles")
    .select("id")
    .eq("role", "admin")
    .single();

  if (existing) return;

  // 创建
  const { data } = await serviceClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (data.user) {
    await serviceClient
      .from("profiles")
      .update({ role: "admin", display_name: "Test Admin" })
      .eq("id", data.user.id);
  }
}
```

---

## 5. RLS 策略测试

### 5.1 为什么重要

> **RLS/RPC 策略就是你的应用逻辑。**  
> 测试的主要目的是证明：用户不能看到或修改他们不该碰的数据。

### 5.2 测试矩阵

必须测试的组合：

| 表            | 操作   | student | parent   | admin |
| ------------- | ------ | ------- | -------- | ----- |
| **questions** | SELECT | ❌      | ❌       | ✅    |
|               | INSERT | ❌      | ❌       | ✅    |
|               | UPDATE | ❌      | ❌       | ✅    |
|               | DELETE | ❌      | ❌       | ✅    |
| **attempts**  | SELECT | 只自己  | 关联学生 | ✅    |
|               | INSERT | 只自己  | ❌       | ✅    |
| **sessions**  | SELECT | 只自己  | 关联学生 | ✅    |
|               | INSERT | 只自己  | ❌       | ✅    |
| **profiles**  | SELECT | 只自己  | 关联     | ✅    |
|               | UPDATE | 只自己  | ❌       | ✅    |

### 5.3 实现方式

参见 [3.3 RLS 策略测试](#33-rls-策略测试) 中的示例代码。

---

## 6. CI/CD 配置

### 6.1 GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  # ============================================
  # Admin Dashboard: Unit + Integration Tests
  # ============================================
  test-admin-dashboard:
    name: Admin Dashboard
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
          cache-dependency-path: web/admin-dashboard/package-lock.json

      - name: Install dependencies
        working-directory: web/admin-dashboard
        run: npm ci

      # Unit Tests (不需要 Supabase)
      - name: Run Unit Tests
        working-directory: web/admin-dashboard
        run: npm run test:unit

      # Integration Tests (需要 Supabase Local)
      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: 1.200.3 # 固定版本

      - name: Cache Supabase
        uses: actions/cache@v4
        with:
          path: ~/.supabase
          key: supabase-${{ runner.os }}-${{ hashFiles('supabase/migrations/*') }}

      - name: Start Supabase Local
        run: |
          supabase start
          supabase db reset

      - name: Run Integration Tests
        working-directory: web/admin-dashboard
        run: npm run test:integration
        env:
          NEXT_PUBLIC_SUPABASE_URL: http://127.0.0.1:54321
          NEXT_PUBLIC_SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}

      - name: Run RLS Tests
        working-directory: web/admin-dashboard
        run: npm run test:rls

      - name: Stop Supabase
        if: always()
        run: supabase stop

  # ============================================
  # Parent Dashboard
  # ============================================
  test-parent-dashboard:
    name: Parent Dashboard
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
          cache-dependency-path: web/parent-dashboard/package-lock.json

      - name: Install dependencies
        working-directory: web/parent-dashboard
        run: npm ci

      - name: Run Tests
        working-directory: web/parent-dashboard
        run: npm run test

  # ============================================
  # Edge Functions
  # ============================================
  test-edge-functions:
    name: Edge Functions
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Deno
        uses: denoland/setup-deno@v1
        with:
          deno-version: v1.x

      - name: Run Tests
        run: deno test --allow-read --allow-env supabase/functions/

  # ============================================
  # iOS
  # ============================================
  test-ios:
    name: iOS (StudentCore)
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v4

      - name: Run Swift Tests
        run: swift test --package-path ios/StudentCore

  # ============================================
  # E2E Tests (仅 main 分支)
  # ============================================
  test-e2e:
    name: E2E Tests
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    needs: [test-admin-dashboard]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
          cache-dependency-path: web/admin-dashboard/package-lock.json

      - name: Install dependencies
        working-directory: web/admin-dashboard
        run: npm ci

      - name: Install Playwright
        working-directory: web/admin-dashboard
        run: npx playwright install --with-deps chromium

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: 1.200.3

      - name: Start Supabase Local
        run: |
          supabase start
          supabase db reset

      - name: Run E2E Tests
        working-directory: web/admin-dashboard
        run: npx playwright test
        env:
          NEXT_PUBLIC_SUPABASE_URL: http://127.0.0.1:54321
          NEXT_PUBLIC_SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
          TEST_ADMIN_EMAIL: admin@test.com
          TEST_ADMIN_PASSWORD: admin123456

      - name: Upload Playwright Report
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: web/admin-dashboard/playwright-report/
          retention-days: 7

      - name: Stop Supabase
        if: always()
        run: supabase stop
```

### 6.2 Branch Protection 配置

在 GitHub 仓库设置中：

```
Settings → Branches → Add rule → main

☑ Require a pull request before merging
☑ Require status checks to pass before merging
  ☑ test-admin-dashboard
  ☑ test-parent-dashboard
  ☑ test-edge-functions
  ☑ test-ios
☑ Require branches to be up to date before merging
```

### 6.3 package.json 脚本

```json
// web/admin-dashboard/package.json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "lint": "next lint",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:unit": "vitest run --config vitest.unit.config.ts",
    "test:integration": "vitest run --config vitest.integration.config.ts",
    "test:rls": "vitest run --config vitest.integration.config.ts test/rls/",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui"
  }
}
```

### 6.4 Vitest 配置

```typescript
// vitest.config.ts (基础配置)
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "node",
    globals: true,
    setupFiles: ["./test/setup.ts"],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});

// vitest.unit.config.ts
import { defineConfig, mergeConfig } from "vitest/config";
import baseConfig from "./vitest.config";

export default mergeConfig(
  baseConfig,
  defineConfig({
    test: {
      include: ["src/**/*.test.ts"],
      exclude: ["src/**/__tests__/**"],
    },
  }),
);

// vitest.integration.config.ts
import { defineConfig, mergeConfig } from "vitest/config";
import baseConfig from "./vitest.config";

export default mergeConfig(
  baseConfig,
  defineConfig({
    test: {
      include: ["src/**/__tests__/**/*.test.ts", "test/**/*.test.ts"],
      testTimeout: 30000, // Integration tests may take longer
      hookTimeout: 30000,
    },
  }),
);
```

---

## 7. 开发者工作流

### 7.1 日常开发流程

```
┌──────────────────────────────────────────────────────────────┐
│                     日常开发流程                              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. 启动开发环境                                              │
│     supabase start                                           │
│     cd web/admin-dashboard && npm run dev                    │
│                                                              │
│  2. 写代码 + 写测试                                           │
│     - 修改 actions.ts                                        │
│     - 在 __tests__/actions.test.ts 添加测试                   │
│                                                              │
│  3. 运行测试 (watch 模式)                                     │
│     npm run test:watch                                       │
│     ❌ 失败 → 修代码 → 自动重跑                                │
│     ✅ 通过 → 继续                                            │
│                                                              │
│  4. 提交前完整测试                                            │
│     npm run test                                             │
│     npm run lint                                             │
│                                                              │
│  5. 提交并推送                                                │
│     git add . && git commit -m "feat: add feature"           │
│     git push                                                 │
│                                                              │
│  6. CI 自动运行                                               │
│     GitHub Actions 自动跑所有测试                             │
│     ✅ 通过 → 可以合并 PR                                     │
│     ❌ 失败 → 修复后重新 push                                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 7.2 测试命令速查

```bash
# ==================== 本地开发 ====================

# 启动 Supabase (Integration/RLS 测试需要)
supabase start

# Unit Tests
npm run test:unit              # 运行一次
npm run test:unit -- --watch   # Watch 模式

# Integration Tests
npm run test:integration       # 运行一次
npm run test:integration -- --watch

# RLS Tests
npm run test:rls

# 所有测试
npm run test

# E2E Tests
npm run test:e2e               # Headless
npm run test:e2e:ui            # UI 模式 (调试)

# ==================== iOS ====================

swift test --package-path ios/StudentCore

# ==================== Edge Functions ====================

deno test --allow-read --allow-env supabase/functions/
```

### 7.3 调试技巧

**Vitest 调试**:

```bash
# 运行单个测试文件
npm run test -- questions/__tests__/actions.test.ts

# 运行匹配名称的测试
npm run test -- -t "creates MCQ question"

# 显示详细输出
npm run test -- --reporter=verbose
```

**Playwright 调试**:

```bash
# UI 模式
npx playwright test --ui

# 显示浏览器
npx playwright test --headed

# 慢动作
npx playwright test --headed --slow-mo=1000

# 调试单个测试
npx playwright test question-crud.spec.ts --debug
```

---

## 8. 文件结构

### 8.1 完整项目结构

```
app-for-sat/
├── .github/
│   └── workflows/
│       └── test.yml                    # CI 配置
│
├── ios/
│   └── StudentCore/
│       ├── Sources/StudentCore/
│       └── Tests/StudentCoreTests/
│           ├── QuestionFeedViewModelTests.swift
│           └── Mocks/
│               └── MockAPIClient.swift
│
├── web/
│   ├── admin-dashboard/
│   │   ├── src/
│   │   │   ├── app/(admin)/admin/
│   │   │   │   ├── questions/
│   │   │   │   │   ├── actions.ts
│   │   │   │   │   └── __tests__/
│   │   │   │   │       └── actions.test.ts
│   │   │   │   ├── tags/
│   │   │   │   │   ├── actions.ts
│   │   │   │   │   └── __tests__/
│   │   │   │   │       └── actions.test.ts
│   │   │   │   └── banks/[id]/questions/
│   │   │   │       ├── actions.ts
│   │   │   │       └── __tests__/
│   │   │   │           └── actions.test.ts
│   │   │   └── lib/
│   │   │       ├── validation.ts
│   │   │       └── validation.test.ts
│   │   ├── test/
│   │   │   ├── setup.ts                # Vitest 全局 setup
│   │   │   ├── helpers.ts              # 测试工具函数
│   │   │   ├── fixtures/
│   │   │   │   ├── questions.ts
│   │   │   │   ├── tags.ts
│   │   │   │   └── users.ts
│   │   │   └── rls/
│   │   │       ├── questions.test.ts
│   │   │       ├── attempts.test.ts
│   │   │       └── sessions.test.ts
│   │   ├── e2e/
│   │   │   ├── fixtures/
│   │   │   │   └── test-import.json
│   │   │   ├── auth.setup.ts
│   │   │   ├── admin-login.spec.ts
│   │   │   ├── question-crud.spec.ts
│   │   │   └── question-import.spec.ts
│   │   ├── vitest.config.ts
│   │   ├── vitest.unit.config.ts
│   │   ├── vitest.integration.config.ts
│   │   └── playwright.config.ts
│   │
│   └── parent-dashboard/
│       └── ... (similar structure)
│
├── supabase/
│   ├── functions/
│   │   ├── _shared/
│   │   │   ├── scoring.ts
│   │   │   └── scoring_test.ts
│   │   ├── submit_attempt/
│   │   │   └── index.ts
│   │   └── sign-asset-upload/
│   │       ├── index.ts
│   │       └── index_test.ts
│   └── migrations/
│
└── tests/
    └── TEST_FRAMEWORK.md               # 本文档
```

---

## 9. 实施路线图

### Phase 1: 基础设施 (Day 1)

| 任务                                         | 预计时间     |
| -------------------------------------------- | ------------ |
| 创建 `test/` 目录结构                        | 15 min       |
| 配置 `vitest.config.ts` (unit + integration) | 30 min       |
| 创建 `test/setup.ts` + `test/helpers.ts`     | 30 min       |
| 创建 `test/fixtures/` 工厂函数               | 30 min       |
| 添加 npm scripts                             | 10 min       |
| **小计**                                     | **~2 hours** |

### Phase 2: Integration Tests (Day 1-2)

| 任务                 | 预计时间       |
| -------------------- | -------------- |
| Questions CRUD tests | 1 hour         |
| Tags CRUD tests      | 30 min         |
| Import RPC tests     | 30 min         |
| Bank Questions tests | 30 min         |
| **小计**             | **~2.5 hours** |

### Phase 3: RLS Tests (Day 2)

| 任务                | 预计时间     |
| ------------------- | ------------ |
| questions RLS tests | 30 min       |
| attempts RLS tests  | 30 min       |
| sessions RLS tests  | 30 min       |
| profiles RLS tests  | 30 min       |
| **小计**            | **~2 hours** |

### Phase 4: CI 配置 (Day 2)

| 任务                              | 预计时间       |
| --------------------------------- | -------------- |
| 创建 `.github/workflows/test.yml` | 30 min         |
| 配置 GitHub Secrets               | 15 min         |
| 配置 Branch Protection            | 15 min         |
| 验证 CI 运行                      | 30 min         |
| **小计**                          | **~1.5 hours** |

### Phase 5: E2E Tests (Day 3)

| 任务                        | 预计时间       |
| --------------------------- | -------------- |
| 配置 `playwright.config.ts` | 20 min         |
| 创建 `auth.setup.ts`        | 20 min         |
| question-crud.spec.ts       | 40 min         |
| question-import.spec.ts     | 30 min         |
| bank-questions.spec.ts      | 30 min         |
| **小计**                    | **~2.5 hours** |

### 总计: ~10.5 hours (2-3 天)

---

## 10. 维护指南

### 10.1 给非工程师的核心认知

> **RLS/RPC 策略就是你的应用逻辑。**
>
> 测试存在的主要目的是证明：**用户不能看到或修改他们不该碰的数据。**
>
> 如果你只理解一件事，就理解：
>
> - **角色（role）如何映射到允许的操作**
> - **一个失败的 policy 如何破坏产品**

### 10.2 何时添加新测试

| 场景               | 需要添加             |
| ------------------ | -------------------- |
| 新增 Server Action | Integration Test     |
| 修改 RLS Policy    | RLS Test             |
| 新增 Edge Function | Deno Test            |
| 新增关键用户路径   | E2E Test             |
| 新增工具函数       | Unit Test            |
| 修复 Bug           | 先写复现测试，再修复 |

### 10.3 测试失败处理

```
CI 测试失败
    │
    ▼
检查失败日志
    │
    ├─→ 测试代码问题 → 修复测试
    │
    ├─→ 业务代码问题 → 修复代码
    │
    └─→ 环境问题 → 检查 CI 配置 / Supabase 版本
```

### 10.4 定期维护

| 频率   | 任务                                            |
| ------ | ----------------------------------------------- |
| 每周   | 检查 CI 运行时间，优化慢测试                    |
| 每月   | 更新依赖版本 (Vitest, Playwright, Supabase CLI) |
| 每季度 | Review 测试覆盖率，补充遗漏场景                 |

### 10.5 常见问题

**Q: 测试通过但生产环境出问题？**
A: 可能是 RLS 策略差异。检查 migrations 是否完全同步。

**Q: CI 偶尔失败（Flaky）？**
A: 常见原因：

- 测试之间有数据依赖（应该隔离）
- 异步操作未正确等待
- Supabase Local 启动未完成

**Q: 测试运行太慢？**
A: 优化方向：

- 减少不必要的 E2E 测试
- 使用事务回滚代替数据删除
- 并行运行测试

---

## 附录

### A. 环境变量

```bash
# .env.test (web/admin-dashboard/)
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<local_anon_key>
SUPABASE_SERVICE_ROLE_KEY=<local_service_role_key>

# E2E Tests
TEST_ADMIN_EMAIL=admin@test.com
TEST_ADMIN_PASSWORD=admin123456
```

### B. GitHub Secrets

需要在 GitHub 仓库设置中添加：

| Secret                      | 来源                   |
| --------------------------- | ---------------------- |
| `SUPABASE_ANON_KEY`         | `supabase status` 输出 |
| `SUPABASE_SERVICE_ROLE_KEY` | `supabase status` 输出 |

### C. 参考资料

- [Vitest Documentation](https://vitest.dev/)
- [Playwright Documentation](https://playwright.dev/)
- [Supabase Testing Guide](https://supabase.com/docs/guides/cli/local-development#testing)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
