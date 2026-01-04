import { describe, it, expect } from "vitest";
import { formatPercent } from "./format";

describe("formatPercent", () => {
  it("formats ratio as percent", () => {
    expect(formatPercent(0.875)).toBe("87.5%");
  });
});
