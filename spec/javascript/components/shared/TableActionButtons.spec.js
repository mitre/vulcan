import { mount } from "@vue/test-utils";
import TableActionButtons from "../../../../app/javascript/components/shared/TableActionButtons.vue";

describe("TableActionButtons", () => {
  const stubs = ["b-button", "b-icon"];

  it("renders edit button when onEdit is provided", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test Project" },
      listeners: { edit: () => {} },
      stubs,
    });
    const editBtn = wrapper.find('[data-testid="action-edit"]');
    expect(editBtn.exists()).toBe(true);
  });

  it("hides edit button when no edit listener", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test" },
      stubs,
    });
    const editBtn = wrapper.find('[data-testid="action-edit"]');
    expect(editBtn.exists()).toBe(false);
  });

  it("renders delete button when onDelete is provided", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test" },
      listeners: { delete: () => {} },
      stubs,
    });
    const deleteBtn = wrapper.find('[data-testid="action-delete"]');
    expect(deleteBtn.exists()).toBe(true);
  });

  it("uses outline-danger for delete and outline-secondary for edit", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test" },
      listeners: { edit: () => {}, delete: () => {} },
      stubs,
    });
    const editBtn = wrapper.find('[data-testid="action-edit"]');
    const deleteBtn = wrapper.find('[data-testid="action-delete"]');
    expect(editBtn.attributes("variant")).toBe("outline-secondary");
    expect(deleteBtn.attributes("variant")).toBe("outline-danger");
  });

  it("sets aria-label with item name", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "My Project" },
      listeners: { edit: () => {}, delete: () => {} },
      stubs,
    });
    expect(wrapper.find('[data-testid="action-edit"]').attributes("aria-label")).toBe("Edit My Project");
    expect(wrapper.find('[data-testid="action-delete"]').attributes("aria-label")).toBe("Remove My Project");
  });

  it("disables buttons when disabled prop is true", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test", disabled: true },
      listeners: { edit: () => {}, delete: () => {} },
      stubs,
    });
    expect(wrapper.find('[data-testid="action-edit"]').attributes("disabled")).toBe("true");
    expect(wrapper.find('[data-testid="action-delete"]').attributes("disabled")).toBe("true");
  });

  it("all buttons use size sm", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test" },
      listeners: { edit: () => {}, delete: () => {} },
      stubs,
    });
    expect(wrapper.find('[data-testid="action-edit"]').attributes("size")).toBe("sm");
    expect(wrapper.find('[data-testid="action-delete"]').attributes("size")).toBe("sm");
  });
});
