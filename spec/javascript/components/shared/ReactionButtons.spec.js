import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ReactionButtons from "@/components/shared/ReactionButtons.vue";

vi.mock("axios", () => ({
  default: {
    get: vi.fn(),
    defaults: { headers: { common: {} } },
  },
}));

import axios from "axios";

const baseProps = (overrides = {}) => ({
  reviewId: 42,
  reactions: { up: 0, down: 0, mine: null },
  ...overrides,
});

describe("ReactionButtons", () => {
  beforeEach(() => {
    axios.get.mockReset();
  });

  it("renders both up and down buttons with counts", () => {
    const w = mount(ReactionButtons, {
      localVue,
      propsData: baseProps({ reactions: { up: 3, down: 1, mine: null } }),
    });
    expect(w.text()).toContain("3");
    expect(w.text()).toContain("1");
  });

  it("emits toggle with kind 'up' when up button clicked", async () => {
    const w = mount(ReactionButtons, { localVue, propsData: baseProps() });
    const buttons = w.findAll("button");
    await buttons.at(0).trigger("click");
    expect(w.emitted("toggle")).toEqual([["up"]]);
  });

  it("emits toggle with kind 'down' when down button clicked", async () => {
    const w = mount(ReactionButtons, { localVue, propsData: baseProps() });
    const buttons = w.findAll("button");
    await buttons.at(1).trigger("click");
    expect(w.emitted("toggle")).toEqual([["down"]]);
  });

  it("marks the up button as pressed when mine === 'up'", () => {
    const w = mount(ReactionButtons, {
      localVue,
      propsData: baseProps({ reactions: { up: 1, down: 0, mine: "up" } }),
    });
    const upButton = w.findAll("button").at(0);
    expect(upButton.attributes("aria-pressed")).toBe("true");
  });

  it("marks the down button as pressed when mine === 'down'", () => {
    const w = mount(ReactionButtons, {
      localVue,
      propsData: baseProps({ reactions: { up: 0, down: 1, mine: "down" } }),
    });
    const downButton = w.findAll("button").at(1);
    expect(downButton.attributes("aria-pressed")).toBe("true");
  });

  it("hides the reactors-trigger when there are no reactions", () => {
    const w = mount(ReactionButtons, { localVue, propsData: baseProps() });
    expect(w.find('[aria-label="Show reactor names"]').exists()).toBe(false);
  });

  it("shows the reactors-trigger when total reactions > 0", () => {
    const w = mount(ReactionButtons, {
      localVue,
      propsData: baseProps({ reactions: { up: 1, down: 0, mine: null } }),
    });
    expect(w.find('[aria-label="Show reactor names"]').exists()).toBe(true);
  });

  it("disables both reaction buttons when disabled prop is true", () => {
    const w = mount(ReactionButtons, {
      localVue,
      propsData: baseProps({ disabled: true }),
    });
    const buttons = w.findAll("button");
    expect(buttons.at(0).attributes("disabled")).toBeDefined();
    expect(buttons.at(1).attributes("disabled")).toBeDefined();
  });

  it("uses closedMessage as the disabled-button title", () => {
    const w = mount(ReactionButtons, {
      localVue,
      propsData: baseProps({
        disabled: true,
        closedMessage: "Reactions are closed — finalized.",
      }),
    });
    const upButton = w.findAll("button").at(0);
    expect(upButton.attributes("title")).toBe("Reactions are closed — finalized.");
  });

  it("calls fetch on first popover show and caches the result", async () => {
    axios.get.mockResolvedValue({
      data: {
        up: [{ name: "Alice" }, { name: "Bob" }],
        down: [{ name: "Carol" }],
      },
    });
    const w = mount(ReactionButtons, {
      localVue,
      propsData: baseProps({ reactions: { up: 2, down: 1, mine: null } }),
    });

    await w.vm.onPopoverShow();
    expect(axios.get).toHaveBeenCalledTimes(1);
    expect(axios.get).toHaveBeenCalledWith("/reviews/42/reactions", {
      headers: { Accept: "application/json" },
    });
    expect(w.vm.reactors.up.map((r) => r.name)).toEqual(["Alice", "Bob"]);
    expect(w.vm.reactors.down.map((r) => r.name)).toEqual(["Carol"]);

    await w.vm.onPopoverShow();
    expect(axios.get).toHaveBeenCalledTimes(1);
  });

  it("invalidates cache when reviewId changes", async () => {
    axios.get.mockResolvedValue({ data: { up: [{ name: "X" }], down: [] } });
    const w = mount(ReactionButtons, {
      localVue,
      propsData: baseProps({ reactions: { up: 1, down: 0, mine: null } }),
    });
    await w.vm.onPopoverShow();
    expect(axios.get).toHaveBeenCalledTimes(1);

    await w.setProps({ reviewId: 99 });
    await w.vm.onPopoverShow();
    expect(axios.get).toHaveBeenCalledTimes(2);
  });

  it("renders an error state when the fetch fails", async () => {
    axios.get.mockRejectedValueOnce(new Error("boom"));
    const w = mount(ReactionButtons, {
      localVue,
      propsData: baseProps({ reactions: { up: 1, down: 0, mine: null } }),
    });
    await w.vm.onPopoverShow();
    await w.vm.$nextTick();
    expect(w.vm.loadError).toBe(true);
  });
});
