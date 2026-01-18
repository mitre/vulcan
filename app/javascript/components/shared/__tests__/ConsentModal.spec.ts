import { shallowMount } from '@vue/test-utils'
import DOMPurify from 'dompurify'
import { marked } from 'marked'
import { beforeEach, describe, expect, it } from 'vitest'
import ConsentModal from '../ConsentModal.vue'

describe('consentModal', () => {
  const defaultProps = {
    show: true,
    title: 'Terms of Use',
    titleAlign: 'center' as const,
    content: '## Terms\n\nTest content',
  }

  beforeEach(() => {
    // Note: We use shallowMount to avoid Reka UI Dialog teleport issues in tests
  })

  describe('markdown rendering', () => {
    it('converts markdown to HTML', () => {
      const content = '## Header\n\n**Bold** text'
      const wrapper = shallowMount(ConsentModal, {
        props: { ...defaultProps, content },
      })

      const vm = wrapper.vm as any
      const html = vm.htmlContent

      expect(html).toContain('<h2')
      expect(html).toContain('Header')
      expect(html).toContain('<strong>')
      expect(html).toContain('Bold')
    })

    it('sanitizes dangerous HTML', () => {
      const content = '## Test\n\n<script>alert("xss")</script>'
      const wrapper = shallowMount(ConsentModal, {
        props: { ...defaultProps, content },
      })

      const vm = wrapper.vm as any
      const html = vm.htmlContent

      expect(html).not.toContain('<script>')
      expect(html).not.toContain('alert')
    })

    it('preserves safe markdown formatting', () => {
      const content = '- Item 1\n- Item 2\n\n**Bold** and *italic*'
      const wrapper = shallowMount(ConsentModal, {
        props: { ...defaultProps, content },
      })

      const vm = wrapper.vm as any
      const html = vm.htmlContent

      expect(html).toContain('<li>')
      expect(html).toContain('Item 1')
      expect(html).toContain('<strong>')
      expect(html).toContain('<em>')
    })
  })

  describe('component behavior', () => {
    it('emits acknowledge event when button clicked', async () => {
      const wrapper = shallowMount(ConsentModal, {
        props: defaultProps,
      })

      await wrapper.vm.handleAcknowledge()

      expect(wrapper.emitted('acknowledge')).toBeTruthy()
      expect(wrapper.emitted('acknowledge')).toHaveLength(1)
    })

    it('receives show prop', () => {
      const wrapper = shallowMount(ConsentModal, {
        props: { ...defaultProps, show: false },
      })

      expect(wrapper.props('show')).toBe(false)
    })

    it('receives title prop', () => {
      const wrapper = shallowMount(ConsentModal, {
        props: { ...defaultProps, title: 'Custom Title' },
      })

      expect(wrapper.props('title')).toBe('Custom Title')
    })

    it('receives titleAlign prop', () => {
      const wrapper = shallowMount(ConsentModal, {
        props: { ...defaultProps, titleAlign: 'left' },
      })

      expect(wrapper.props('titleAlign')).toBe('left')
    })

    it('receives content prop', () => {
      const content = '## Custom content'
      const wrapper = shallowMount(ConsentModal, {
        props: { ...defaultProps, content },
      })

      expect(wrapper.props('content')).toBe(content)
    })
  })

  describe('markdown+DOMPurify integration', () => {
    it('uses marked to parse markdown', () => {
      const markdown = '## Test'
      const result = marked.parse(markdown) as string

      expect(result).toContain('<h2')
      expect(result).toContain('Test')
    })

    it('uses DOMPurify to sanitize HTML', () => {
      const dirty = '<script>alert("xss")</script><p>Safe</p>'
      const clean = DOMPurify.sanitize(dirty)

      expect(clean).not.toContain('<script>')
      expect(clean).toContain('<p>Safe</p>')
    })
  })
})
