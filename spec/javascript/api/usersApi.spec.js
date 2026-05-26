import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import {
  searchUsers,
  createUser,
  updateUser,
  deleteUser,
  lockUser,
  unlockUser,
  sendPasswordReset,
  generateResetLink,
  setPassword,
  updateProfile,
  deleteAccount,
  unlinkIdentity,
} from "@/api/usersApi";

vi.mock("@/api/baseApi", () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), delete: vi.fn(), patch: vi.fn() },
}));

describe("usersApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("searchUsers calls GET /api/users/search with query", async () => {
    api.get.mockResolvedValue({ data: [] });
    await searchUsers("alice");
    expect(api.get).toHaveBeenCalledWith("/api/users/search", { params: { q: "alice" } });
  });

  it("searchUsers passes extra params when provided", async () => {
    api.get.mockResolvedValue({ data: [] });
    await searchUsers("bob", { membership_type: "Project", membership_id: 5 });
    expect(api.get).toHaveBeenCalledWith("/api/users/search", {
      params: { q: "bob", membership_type: "Project", membership_id: 5 },
    });
  });

  it("createUser calls POST /users/admin_create", async () => {
    api.post.mockResolvedValue({ data: {} });
    await createUser({ email: "a@b.com", name: "A" });
    expect(api.post).toHaveBeenCalledWith("/users/admin_create", {
      user: { email: "a@b.com", name: "A" },
    });
  });

  it("updateUser calls PUT /users/:id", async () => {
    api.put.mockResolvedValue({ data: {} });
    await updateUser(5, { admin: true });
    expect(api.put).toHaveBeenCalledWith("/users/5", { user: { admin: true } });
  });

  it("deleteUser calls DELETE /users/:id", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await deleteUser(5);
    expect(api.delete).toHaveBeenCalledWith("/users/5");
  });

  it("lockUser calls POST /users/:id/lock", async () => {
    api.post.mockResolvedValue({ data: {} });
    await lockUser(3);
    expect(api.post).toHaveBeenCalledWith("/users/3/lock");
  });

  it("unlockUser calls POST /users/:id/unlock", async () => {
    api.post.mockResolvedValue({ data: {} });
    await unlockUser(3);
    expect(api.post).toHaveBeenCalledWith("/users/3/unlock");
  });

  it("sendPasswordReset calls POST /users/:id/send_password_reset", async () => {
    api.post.mockResolvedValue({ data: {} });
    await sendPasswordReset(3);
    expect(api.post).toHaveBeenCalledWith("/users/3/send_password_reset");
  });

  it("generateResetLink calls POST /users/:id/generate_reset_link", async () => {
    api.post.mockResolvedValue({ data: {} });
    await generateResetLink(3);
    expect(api.post).toHaveBeenCalledWith("/users/3/generate_reset_link");
  });

  it("setPassword calls POST /users/:id/set_password", async () => {
    api.post.mockResolvedValue({ data: {} });
    await setPassword(3, "new123", "new123");
    expect(api.post).toHaveBeenCalledWith("/users/3/set_password", {
      user: { password: "new123", password_confirmation: "new123" },
    });
  });

  it("updateProfile calls PUT /users with user payload", async () => {
    api.put.mockResolvedValue({ data: {} });
    await updateProfile({ name: "New Name" });
    expect(api.put).toHaveBeenCalledWith("/users", { user: { name: "New Name" } });
  });

  it("deleteAccount calls DELETE /users", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await deleteAccount();
    expect(api.delete).toHaveBeenCalledWith("/users");
  });

  it("unlinkIdentity calls POST /users/unlink_identity with payload", async () => {
    api.post.mockResolvedValue({ data: {} });
    await unlinkIdentity({ provider: "github" });
    expect(api.post).toHaveBeenCalledWith("/users/unlink_identity", { provider: "github" });
  });

  it("unlinkIdentity accepts current_password payload", async () => {
    api.post.mockResolvedValue({ data: {} });
    await unlinkIdentity({ current_password: "secret123" });
    expect(api.post).toHaveBeenCalledWith("/users/unlink_identity", { current_password: "secret123" });
  });

  describe("error propagation", () => {
    it("updateUser propagates rejected promise", async () => {
      api.put.mockRejectedValue(new Error("404 Not Found"));
      await expect(updateUser(999, { name: "x" })).rejects.toThrow("404 Not Found");
    });
  });
});
