import { describe, it, expect } from "vitest";
import { roleGteTo, ROLE_HIERARCHY } from "../../../app/javascript/utils/roleComparison";

describe("roleGteTo", () => {
  it("returns true when roles are equal", () => {
    expect(roleGteTo("viewer", "viewer")).toBe(true);
    expect(roleGteTo("author", "author")).toBe(true);
    expect(roleGteTo("reviewer", "reviewer")).toBe(true);
    expect(roleGteTo("admin", "admin")).toBe(true);
  });

  it("returns true when effective role is higher than required", () => {
    expect(roleGteTo("admin", "viewer")).toBe(true);
    expect(roleGteTo("admin", "author")).toBe(true);
    expect(roleGteTo("admin", "reviewer")).toBe(true);
    expect(roleGteTo("reviewer", "author")).toBe(true);
    expect(roleGteTo("author", "viewer")).toBe(true);
  });

  it("returns false when effective role is lower than required", () => {
    expect(roleGteTo("viewer", "author")).toBe(false);
    expect(roleGteTo("viewer", "reviewer")).toBe(false);
    expect(roleGteTo("viewer", "admin")).toBe(false);
    expect(roleGteTo("author", "reviewer")).toBe(false);
    expect(roleGteTo("author", "admin")).toBe(false);
    expect(roleGteTo("reviewer", "admin")).toBe(false);
  });

  it("returns false when effectiveRole is null", () => {
    expect(roleGteTo(null, "viewer")).toBe(false);
    expect(roleGteTo(null, "admin")).toBe(false);
  });

  it("returns false when effectiveRole is undefined", () => {
    expect(roleGteTo(undefined, "viewer")).toBe(false);
  });

  it("returns false when requiredRole is null", () => {
    expect(roleGteTo("admin", null)).toBe(false);
  });

  it("returns false for unrecognized role strings", () => {
    expect(roleGteTo("superadmin", "admin")).toBe(false);
    expect(roleGteTo("admin", "superadmin")).toBe(false);
  });
});

describe("ROLE_HIERARCHY", () => {
  it("defines the correct order: viewer < author < reviewer < admin", () => {
    expect(ROLE_HIERARCHY).toEqual(["viewer", "author", "reviewer", "admin"]);
  });
});
