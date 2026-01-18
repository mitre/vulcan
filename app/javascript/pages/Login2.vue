<script setup lang="ts">
import { computed, ref } from 'vue'
import { useColorMode } from '@/composables'
import { useAppToast } from '@/composables/useToast'
import { useAuthStore } from '@/stores'

const authStore = useAuthStore()
const toast = useAppToast()
const { colorMode, resolvedMode, cycleColorMode } = useColorMode()

const email = ref('')
const password = ref('')
const rememberMe = ref(false)
const showPassword = ref(false)
const loading = ref(false)
const error = ref('')

// Redacted characters effect
const redactedChars = computed(() => {
  if (showPassword.value || password.value.length === 0) return []
  // Show redaction for all but last 2 characters
  return password.value.slice(0, -2).split('')
})

function handlePasswordInput() {
  // Clear error on input
  if (error.value) error.value = ''
}

async function handleLogin() {
  loading.value = true
  error.value = ''

  try {
    await authStore.login({ email: email.value, password: password.value })
    // On success, redirect to projects
    window.location.href = '/projects'
  }
  catch (err: any) {
    // Format error in classified style
    const errorMsg = err.response?.data?.error || err.message || 'INVALID CREDENTIALS'
    error.value = `AUTHENTICATION FAILED: ${errorMsg.toUpperCase()}`
    loading.value = false
  }
}
</script>

<template>
  <div class="classified-login">
    <!-- Scanline overlay for CRT effect -->
    <div class="scanlines" />

    <!-- Background grid -->
    <div class="grid-background" />

    <!-- Main login card -->
    <div class="login-container">
      <!-- Classification banner -->
      <div class="classification-banner">
        <div class="classification-stripe" />
        <div class="classification-text">
          UNCLASSIFIED
        </div>
        <div class="classification-stripe" />
      </div>

      <!-- Logo and title -->
      <div class="header">
        <div class="logo-lockup">
          <div class="vulcan-seal">
            <svg viewBox="0 0 100 100" class="seal-svg">
              <circle cx="50" cy="50" r="45" stroke="currentColor" stroke-width="2" fill="none" />
              <circle cx="50" cy="50" r="40" stroke="currentColor" stroke-width="1" fill="none" />
              <text x="50" y="55" text-anchor="middle" font-size="24" font-weight="700">V</text>
            </svg>
          </div>
          <div class="title-block">
            <h1 class="system-title">
              VULCAN
            </h1>
            <p class="system-subtitle">
              STIG READY SECURITY GUIDANCE SYSTEM
            </p>
          </div>
        </div>

        <div class="classification-notice">
          <span class="redacted-block" />
          <span class="notice-text">AUTHORIZED PERSONNEL ONLY</span>
          <span class="redacted-block" />
        </div>
      </div>

      <!-- Login form -->
      <form class="login-form" @submit.prevent="handleLogin">
        <div class="form-group">
          <label for="email" class="form-label">
            <span class="label-prefix">//</span>
            <span class="label-text">USER IDENTIFICATION</span>
          </label>
          <input
            id="email"
            v-model="email"
            type="email"
            class="form-input"
            placeholder="user@domain.mil"
            required
            autocomplete="email"
          >
          <div class="input-underline" />
        </div>

        <div class="form-group">
          <label for="password" class="form-label">
            <span class="label-prefix">//</span>
            <span class="label-text">ACCESS CREDENTIAL</span>
          </label>
          <div class="password-container">
            <input
              id="password"
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              class="form-input password-input"
              placeholder="•••••••••••"
              required
              autocomplete="current-password"
              @input="handlePasswordInput"
            >
            <div class="redaction-overlay">
              <span
                v-for="(char, index) in redactedChars"
                :key="index"
                class="redacted-char"
                :style="{ animationDelay: `${index * 50}ms` }"
              >█</span>
            </div>
            <button
              type="button"
              class="password-toggle"
              :aria-label="showPassword ? 'Hide password' : 'Show password'"
              @click="showPassword = !showPassword"
            >
              <span v-if="showPassword">⊗</span>
              <span v-else>◉</span>
            </button>
          </div>
          <div class="input-underline" />
        </div>

        <!-- Remember me checkbox -->
        <div class="form-options">
          <label class="checkbox-label">
            <input v-model="rememberMe" type="checkbox" class="checkbox-input">
            <span class="checkbox-custom" />
            <span class="checkbox-text">MAINTAIN SESSION</span>
          </label>
        </div>

        <!-- Submit button -->
        <button type="submit" class="submit-button" :disabled="loading">
          <span v-if="!loading" class="button-content">
            <span class="button-icon">►</span>
            <span class="button-text">AUTHENTICATE</span>
            <span class="button-trail" />
          </span>
          <span v-else class="button-loading">
            <span class="spinner" />
            <span class="button-text">VERIFYING...</span>
          </span>
        </button>

        <!-- Error message -->
        <div v-if="error" class="error-message">
          <span class="error-icon">⚠</span>
          <span class="error-text">{{ error }}</span>
        </div>
      </form>

      <!-- Footer links -->
      <div class="footer-links">
        <a href="#" class="footer-link">RESET CREDENTIALS</a>
        <span class="footer-divider">|</span>
        <a href="#" class="footer-link">SYSTEM STATUS</a>
      </div>

      <!-- Classification banner bottom -->
      <div class="classification-banner bottom">
        <div class="classification-stripe" />
        <div class="classification-text">
          UNCLASSIFIED
        </div>
        <div class="classification-stripe" />
      </div>
    </div>

    <!-- Theme toggle -->
    <button class="theme-toggle" :title="`Theme: ${colorMode}`" @click="cycleColorMode">
      <span v-if="resolvedMode === 'dark'">☼</span>
      <span v-else>☾</span>
    </button>

    <!-- System info footer -->
    <div class="system-info">
      <div class="info-item">
        SYS.VERSION: 2.3.0
      </div>
      <div class="info-divider">
        •
      </div>
      <div class="info-item">
        PROTO: HTTPS/TLS
      </div>
      <div class="info-divider">
        •
      </div>
      <div class="info-item">
        AUTH: MULTI-FACTOR
      </div>
      <div class="info-divider">
        •
      </div>
      <div class="info-item">
        THEME: {{ colorMode.toUpperCase() }}
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Dark mode (default) */
:root {
  --classified-bg: #0a0a0a;
  --classified-paper: #1a1a1a;
  --classified-text: #e0e0e0;
  --classified-red: #d32f2f;
  --classified-green: #00ff41;
  --classified-yellow: #ffd700;
  --border-color: #333;
  --grid-color: rgba(255, 255, 255, 0.02);
  --shadow-color: rgba(211, 47, 47, 0.1);
  --scanline-color: rgba(0, 0, 0, 0.15);
}

/* Light mode - "Classified Document" aesthetic */
[data-bs-theme="light"] .classified-login {
  --classified-bg: #f5f5f0;  /* Aged paper background */
  --classified-paper: #ffffff;  /* White document */
  --classified-text: #1a1a1a;  /* Black text */
  --classified-red: #c62828;  /* Darker red for contrast */
  --classified-green: #2e7d32;  /* Dark green */
  --classified-yellow: #f57c00;  /* Orange instead of yellow */
  --border-color: #d0d0d0;  /* Light gray border */
  --grid-color: rgba(0, 0, 0, 0.03);  /* Subtle grid */
  --shadow-color: rgba(198, 40, 40, 0.15);  /* Red shadow */
  --scanline-color: rgba(0, 0, 0, 0.02);  /* Lighter scanlines */
}

[data-bs-theme="light"] .form-input {
  background: rgba(0, 0, 0, 0.02);
  color: var(--classified-text);
  border-color: var(--border-color);
}

[data-bs-theme="light"] .form-input:focus {
  background: rgba(198, 40, 40, 0.05);
}

[data-bs-theme="light"] .form-input::placeholder {
  color: rgba(0, 0, 0, 0.3);
}

[data-bs-theme="light"] .submit-button {
  background: var(--classified-red);
  border-color: var(--classified-red);
  color: white;
}

[data-bs-theme="light"] .submit-button:hover:not(:disabled) {
  background: #a02020;
  border-color: #a02020;
  color: white;
}

[data-bs-theme="light"] .system-info,
[data-bs-theme="light"] .footer-link {
  color: rgba(0, 0, 0, 0.5);
}

[data-bs-theme="light"] .footer-link:hover {
  color: var(--classified-red);
}

[data-bs-theme="light"] .checkbox-text,
[data-bs-theme="light"] .label-text {
  color: rgba(0, 0, 0, 0.7);
}

[data-bs-theme="light"] .label-prefix {
  color: var(--classified-red);
}

[data-bs-theme="light"] .redacted-block {
  background: var(--classified-text);
}

[data-bs-theme="light"] .grid-background {
  opacity: 0.5;
}

[data-bs-theme="light"] .vulcan-seal {
  color: var(--classified-red);
}

[data-bs-theme="light"] .system-title {
  color: var(--classified-text);
  text-shadow: none;
}

[data-bs-theme="light"] .password-toggle {
  color: rgba(0, 0, 0, 0.4);
}

[data-bs-theme="light"] .password-toggle:hover {
  color: var(--classified-red);
}

.classified-login {
  /* Fullscreen - override any parent containers */
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  min-height: 100vh;
  background: var(--classified-bg);
  color: var(--classified-text);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  overflow: hidden;
  font-family: 'Courier New', 'Consolas', monospace;
  z-index: 9999; /* Above navbar/footer */
}

/* CRT Scanline effect */
.scanlines {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  background:
    repeating-linear-gradient(
      0deg,
      var(--scanline-color),
      var(--scanline-color) 1px,
      transparent 1px,
      transparent 2px
    );
  animation: scanline 8s linear infinite;
  z-index: 10;
}

@keyframes scanline {
  0% { transform: translateY(0); }
  100% { transform: translateY(100%); }
}

/* Background grid */
.grid-background {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-image:
    linear-gradient(var(--grid-color) 1px, transparent 1px),
    linear-gradient(90deg, var(--grid-color) 1px, transparent 1px);
  background-size: 50px 50px;
  opacity: 0.3;
}

/* Login container */
.login-container {
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: 480px;
  background: var(--classified-paper);
  border: 2px solid var(--border-color);
  box-shadow:
    0 0 40px var(--shadow-color),
    0 8px 32px rgba(0, 0, 0, 0.1);
  animation: fadeInUp 0.6s ease-out;
}

@media (prefers-color-scheme: light) {
  .login-container {
    box-shadow:
      0 0 40px var(--shadow-color),
      0 8px 32px rgba(0, 0, 0, 0.08),
      inset 0 1px 0 rgba(255, 255, 255, 0.8);
  }
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* Classification banners */
.classification-banner {
  display: flex;
  align-items: center;
  gap: 1rem;
  background: var(--classified-red);
  padding: 0.5rem 1.5rem;
  font-weight: 700;
  letter-spacing: 0.15em;
  font-size: 0.75rem;
}

.classification-banner.bottom {
  margin-top: 2rem;
}

.classification-stripe {
  flex: 1;
  height: 2px;
  background: rgba(255, 255, 255, 0.5);
}

.classification-text {
  color: white;
  white-space: nowrap;
}

/* Header */
.header {
  padding: 2.5rem 2rem 2rem;
  border-bottom: 1px solid var(--border-color);
}

.logo-lockup {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  margin-bottom: 1.5rem;
}

.vulcan-seal {
  width: 60px;
  height: 60px;
  color: var(--classified-red);
  filter: drop-shadow(0 0 10px rgba(211, 47, 47, 0.5));
  animation: pulseGlow 3s ease-in-out infinite;
}

@keyframes pulseGlow {
  0%, 100% { filter: drop-shadow(0 0 10px rgba(211, 47, 47, 0.5)); }
  50% { filter: drop-shadow(0 0 20px rgba(211, 47, 47, 0.8)); }
}

.seal-svg {
  width: 100%;
  height: 100%;
}

.title-block {
  flex: 1;
}

.system-title {
  font-size: 2rem;
  font-weight: 700;
  letter-spacing: 0.3em;
  margin: 0;
  color: var(--classified-text);
  text-shadow: 0 0 20px rgba(255, 255, 255, 0.1);
}

.system-subtitle {
  font-size: 0.65rem;
  letter-spacing: 0.2em;
  margin: 0.25rem 0 0;
  color: rgba(255, 255, 255, 0.5);
  font-weight: 400;
}

.classification-notice {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-size: 0.7rem;
  letter-spacing: 0.15em;
  color: var(--classified-yellow);
}

.redacted-block {
  width: 40px;
  height: 8px;
  background: currentColor;
  opacity: 0.6;
}

.notice-text {
  flex: 1;
  text-align: center;
}

/* Form */
.login-form {
  padding: 2rem;
}

.form-group {
  margin-bottom: 2rem;
  position: relative;
}

.form-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
  font-size: 0.75rem;
  letter-spacing: 0.1em;
  color: rgba(255, 255, 255, 0.7);
}

.label-prefix {
  color: var(--classified-red);
  font-weight: 700;
}

.label-text {
  font-weight: 600;
}

.form-input {
  width: 100%;
  background: rgba(0, 0, 0, 0.4);
  border: 1px solid var(--border-color);
  border-radius: 0;
  padding: 1rem;
  font-family: 'Courier New', monospace;
  font-size: 0.95rem;
  color: var(--classified-text);
  letter-spacing: 0.05em;
  transition: all 0.3s ease;
  outline: none;
}

.form-input:focus {
  border-color: var(--classified-red);
  background: rgba(211, 47, 47, 0.05);
  box-shadow: 0 0 0 1px var(--classified-red);
}

.form-input::placeholder {
  color: rgba(255, 255, 255, 0.3);
  letter-spacing: 0.2em;
}

.input-underline {
  height: 1px;
  background: linear-gradient(
    90deg,
    transparent,
    var(--classified-red) 30%,
    var(--classified-red) 70%,
    transparent
  );
  transform: scaleX(0);
  transition: transform 0.3s ease;
  margin-top: -1px;
}

.form-input:focus + .input-underline {
  transform: scaleX(1);
}

/* Password field with redaction effect */
.password-container {
  position: relative;
}

.password-input {
  position: relative;
  z-index: 1;
}

.redaction-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 40px;
  bottom: 0;
  padding: 1rem;
  pointer-events: none;
  display: flex;
  gap: 0.5rem;
  align-items: center;
  z-index: 2;
  font-family: 'Courier New', monospace;
}

.redacted-char {
  color: #000;
  background: #000;
  font-size: 1.2rem;
  line-height: 1;
  animation: redact 0.3s ease-out forwards;
  opacity: 0;
}

@keyframes redact {
  from {
    opacity: 0;
    transform: scaleX(0);
  }
  to {
    opacity: 0.9;
    transform: scaleX(1);
  }
}

.password-toggle {
  position: absolute;
  right: 1rem;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: rgba(255, 255, 255, 0.4);
  font-size: 1.2rem;
  cursor: pointer;
  padding: 0.5rem;
  z-index: 3;
  transition: color 0.2s;
}

.password-toggle:hover {
  color: var(--classified-red);
}

/* Checkbox */
.form-options {
  margin-bottom: 2rem;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  cursor: pointer;
  user-select: none;
  font-size: 0.75rem;
  letter-spacing: 0.1em;
}

.checkbox-input {
  position: absolute;
  opacity: 0;
}

.checkbox-custom {
  width: 18px;
  height: 18px;
  border: 2px solid var(--border-color);
  position: relative;
  transition: all 0.2s;
}

.checkbox-input:checked + .checkbox-custom {
  background: var(--classified-red);
  border-color: var(--classified-red);
}

.checkbox-input:checked + .checkbox-custom::after {
  content: '✓';
  position: absolute;
  top: -2px;
  left: 2px;
  color: white;
  font-size: 0.85rem;
  font-weight: 700;
}

.checkbox-text {
  color: rgba(255, 255, 255, 0.6);
}

/* Submit button */
.submit-button {
  width: 100%;
  background: var(--classified-red);
  border: 2px solid var(--classified-red);
  color: white;
  padding: 1rem 2rem;
  font-family: 'Courier New', monospace;
  font-size: 0.85rem;
  font-weight: 700;
  letter-spacing: 0.15em;
  cursor: pointer;
  position: relative;
  overflow: hidden;
  transition: all 0.3s ease;
}

.submit-button:hover:not(:disabled) {
  background: transparent;
  color: var(--classified-red);
  box-shadow:
    0 0 20px rgba(211, 47, 47, 0.3),
    inset 0 0 20px rgba(211, 47, 47, 0.1);
}

.submit-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.button-content {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
}

.button-icon {
  font-size: 1rem;
  animation: blink 1.5s infinite;
}

@keyframes blink {
  0%, 49% { opacity: 1; }
  50%, 100% { opacity: 0.3; }
}

.button-trail {
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(
    90deg,
    transparent,
    rgba(255, 255, 255, 0.3),
    transparent
  );
  animation: trail 3s infinite;
}

@keyframes trail {
  0% { left: -100%; }
  100% { left: 100%; }
}

.button-loading {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
}

.spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Error message */
.error-message {
  margin-top: 1.5rem;
  padding: 1rem;
  background: rgba(211, 47, 47, 0.1);
  border: 1px solid var(--classified-red);
  border-left: 4px solid var(--classified-red);
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-size: 0.8rem;
  letter-spacing: 0.05em;
  animation: shake 0.4s ease-out;
}

@keyframes shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-8px); }
  75% { transform: translateX(8px); }
}

.error-icon {
  color: var(--classified-red);
  font-size: 1.2rem;
  animation: pulse 0.6s ease-out;
}

@keyframes pulse {
  0% { transform: scale(1); }
  50% { transform: scale(1.3); }
  100% { transform: scale(1); }
}

.error-text {
  flex: 1;
  color: var(--classified-red);
  font-weight: 600;
}

/* Footer links */
.footer-links {
  padding: 1.5rem 2rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  border-top: 1px solid var(--border-color);
  font-size: 0.7rem;
  letter-spacing: 0.1em;
}

.footer-link {
  color: rgba(255, 255, 255, 0.5);
  text-decoration: none;
  transition: color 0.2s;
  position: relative;
}

.footer-link::after {
  content: '';
  position: absolute;
  bottom: -2px;
  left: 0;
  width: 0;
  height: 1px;
  background: var(--classified-red);
  transition: width 0.3s ease;
}

.footer-link:hover {
  color: var(--classified-red);
}

.footer-link:hover::after {
  width: 100%;
}

.footer-divider {
  color: rgba(255, 255, 255, 0.2);
}

/* System info */
.system-info {
  position: fixed;
  bottom: 1rem;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  align-items: center;
  gap: 1rem;
  font-size: 0.65rem;
  letter-spacing: 0.1em;
  color: rgba(255, 255, 255, 0.3);
  font-family: 'Courier New', monospace;
  z-index: 5;
}

.info-divider {
  opacity: 0.5;
}

/* Responsive */
@media (max-width: 640px) {
  .login-container {
    max-width: 100%;
  }

  .system-title {
    font-size: 1.5rem;
    letter-spacing: 0.2em;
  }

  .logo-lockup {
    flex-direction: column;
    text-align: center;
  }

  .system-info {
    flex-direction: column;
    gap: 0.25rem;
  }

  .info-divider {
    display: none;
  }
}

/* Accessibility */
@media (prefers-reduced-motion: reduce) {
  .scanlines,
  .button-trail,
  .classified-login,
  .redacted-char {
    animation: none;
  }
}

/* Theme toggle button */
.theme-toggle {
  position: fixed;
  top: 1.5rem;
  right: 1.5rem;
  width: 48px;
  height: 48px;
  background: rgba(0, 0, 0, 0.3);
  border: 1px solid var(--border-color);
  color: var(--classified-text);
  font-size: 1.5rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s ease;
  z-index: 100;
  backdrop-filter: blur(10px);
}

.theme-toggle:hover {
  background: var(--classified-red);
  border-color: var(--classified-red);
  color: white;
  transform: rotate(180deg);
}

[data-bs-theme="light"] .theme-toggle {
  background: rgba(255, 255, 255, 0.8);
  border-color: var(--border-color);
}

[data-bs-theme="light"] .theme-toggle:hover {
  background: var(--classified-red);
  color: white;
}

/* High contrast mode */
@media (prefers-contrast: high) {
  .form-input {
    border-width: 2px;
  }

  .classification-banner {
    border: 2px solid white;
  }
}
</style>
