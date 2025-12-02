import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import SearchInput from '../SearchInput.vue'

describe('searchInput', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  describe('rendering', () => {
    it('renders with search icon', () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
        },
      })

      expect(wrapper.find('.bi-search').exists()).toBe(true)
    })

    it('renders input with value', () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: 'test',
        },
      })

      const input = wrapper.find('input')
      expect(input.element.value).toBe('test')
    })

    it('uses default placeholder', () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
        },
      })

      expect(wrapper.find('input').attributes('placeholder')).toBe('Search...')
    })

    it('uses custom placeholder', () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
          placeholder: 'Find users...',
        },
      })

      expect(wrapper.find('input').attributes('placeholder')).toBe('Find users...')
    })
  })

  describe('sizes', () => {
    it('applies small size class', () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
          size: 'sm',
        },
      })

      expect(wrapper.find('.input-group').classes()).toContain('input-group-sm')
    })

    it('applies large size class', () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
          size: 'lg',
        },
      })

      expect(wrapper.find('.input-group').classes()).toContain('input-group-lg')
    })

    it('does not apply size class for md (default)', () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
          size: 'md',
        },
      })

      expect(wrapper.find('.input-group').classes()).not.toContain('input-group-md')
    })
  })

  describe('clear button', () => {
    it('shows clear button when has value', () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: 'test',
        },
      })

      expect(wrapper.find('button').exists()).toBe(true)
      expect(wrapper.find('.bi-x').exists()).toBe(true)
    })

    it('hides clear button when empty', () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
        },
      })

      expect(wrapper.find('button').exists()).toBe(false)
    })

    it('emits empty string when clear button clicked', async () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: 'test',
        },
      })

      await wrapper.find('button').trigger('click')
      expect(wrapper.emitted('update:modelValue')).toBeTruthy()
      expect(wrapper.emitted('update:modelValue')![0]).toEqual([''])
    })
  })

  describe('input events', () => {
    it('emits update:modelValue on input', async () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
        },
      })

      const input = wrapper.find('input')
      await input.setValue('test')

      expect(wrapper.emitted('update:modelValue')).toBeTruthy()
      expect(wrapper.emitted('update:modelValue')![0]).toEqual(['test'])
    })
  })

  describe('debounce', () => {
    it('debounces input when debounce prop is set', async () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
          debounce: 300,
        },
      })

      const input = wrapper.find('input')
      const inputEl = input.element as HTMLInputElement

      // Set value and trigger input event
      inputEl.value = 'test'
      await input.trigger('input')

      // Should not emit immediately
      expect(wrapper.emitted('update:modelValue')).toBeFalsy()

      // Fast forward time
      vi.advanceTimersByTime(300)

      // Should emit after debounce
      expect(wrapper.emitted('update:modelValue')).toBeTruthy()
    })

    it('does not debounce when debounce is 0', async () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
          debounce: 0,
        },
      })

      const input = wrapper.find('input')
      await input.setValue('test')

      // Should emit immediately
      expect(wrapper.emitted('update:modelValue')).toBeTruthy()
    })

    it('cancels previous debounce on new input', async () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: '',
          debounce: 300,
        },
      })

      const input = wrapper.find('input')
      const inputEl = input.element as HTMLInputElement

      // First input
      inputEl.value = 'test1'
      await input.trigger('input')

      // Wait halfway
      vi.advanceTimersByTime(150)

      // Second input
      inputEl.value = 'test2'
      await input.trigger('input')

      // Wait for full debounce
      vi.advanceTimersByTime(300)

      // Should only emit once with final value
      const emitted = wrapper.emitted('update:modelValue')
      expect(emitted).toHaveLength(1)
      expect(emitted![0]).toEqual(['test2'])
    })
  })

  describe('accessibility', () => {
    it('has aria-label on clear button', () => {
      const wrapper = mount(SearchInput, {
        props: {
          modelValue: 'test',
        },
      })

      expect(wrapper.find('button').attributes('aria-label')).toBe('Clear search')
    })
  })
})
