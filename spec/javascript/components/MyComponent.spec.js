import { shallowMount } from '@vue/test-utils'
import MyComponent from '@/components/MyComponent'

describe('MyComponent', () => {
  it('renders properly', () => {
    const wrapper = shallowMount(MyComponent)
    expect(wrapper.exists()).toBe(true)
  })

  it('accepts a prop', () => {
    const wrapper = shallowMount(MyComponent, {
      propsData: {
        message: 'Hello World'
      }
    })
    expect(wrapper.text()).toContain('Hello World')
  })

  it('updates data when a method is called', async () => {
    const wrapper = shallowMount(MyComponent)
    await wrapper.vm.updateMessage()
    expect(wrapper.vm.internalMessage).toBe('Updated Message')
  })
})
