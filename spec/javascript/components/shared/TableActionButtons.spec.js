import { mount } from "@vue/test-utils";
import TableActionButtons from "../../../../app/javascript/components/shared/TableActionButtons.vue";

describe("TableActionButtons", () => {
  const stubs = ["b-button", "b-icon"];

  it("renders edit button when showEdit is true", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test Project", showEdit: true },
      stubs,
    });
    const editBtn = wrapper.find('[data-testid="action-edit"]');
    expect(editBtn.exists()).toBe(true);
  });

  it("hides edit button by default (showEdit defaults to false)", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test" },
      stubs,
    });
    const editBtn = wrapper.find('[data-testid="action-edit"]');
    expect(editBtn.exists()).toBe(false);
  });

  it("renders delete button by default (showDelete defaults to true)", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test" },
      stubs,
    });
    const deleteBtn = wrapper.find('[data-testid="action-delete"]');
    expect(deleteBtn.exists()).toBe(true);
  });

  it("hides delete button when showDelete is false", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test", showDelete: false },
      stubs,
    });
    const deleteBtn = wrapper.find('[data-testid="action-delete"]');
    expect(deleteBtn.exists()).toBe(false);
  });

  it("uses outline-danger for delete and outline-secondary for edit", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test", showEdit: true, showDelete: true },
      stubs,
    });
    const editBtn = wrapper.find('[data-testid="action-edit"]');
    const deleteBtn = wrapper.find('[data-testid="action-delete"]');
    expect(editBtn.attributes("variant")).toBe("outline-secondary");
    expect(deleteBtn.attributes("variant")).toBe("outline-danger");
  });

  it("sets aria-label with item name", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "My Project", showEdit: true, showDelete: true },
      stubs,
    });
    expect(wrapper.find('[data-testid="action-edit"]').attributes("aria-label")).toBe("Edit My Project");
    expect(wrapper.find('[data-testid="action-delete"]').attributes("aria-label")).toBe("Remove My Project");
  });

  it("disables buttons when disabled prop is true", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test", disabled: true, showEdit: true, showDelete: true },
      stubs,
    });
    expect(wrapper.find('[data-testid="action-edit"]').attributes("disabled")).toBe("true");
    expect(wrapper.find('[data-testid="action-delete"]').attributes("disabled")).toBe("true");
  });

  it("all buttons use size sm", () => {
    const wrapper = mount(TableActionButtons, {
      propsData: { itemName: "Test", showEdit: true, showDelete: true },
      stubs,
    });
    expect(wrapper.find('[data-testid="action-edit"]').attributes("size")).toBe("sm");
    expect(wrapper.find('[data-testid="action-delete"]').attributes("size")).toBe("sm");
  });
});
