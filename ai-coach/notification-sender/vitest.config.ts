import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary"],
      thresholds: {
        lines: 10,
        functions: 10,
        branches: 5,
        statements: 10,
      },
    },
  },
});
