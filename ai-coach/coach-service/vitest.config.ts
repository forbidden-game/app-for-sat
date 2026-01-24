import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary"],
      thresholds: {
        lines: 15,
        functions: 15,
        branches: 8,
        statements: 15,
      },
    },
  },
});
