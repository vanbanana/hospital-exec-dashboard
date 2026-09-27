<template>
  <div class="auth-layout">
    <div class="login-card">
      <!-- 品牌区：hospital/profile 为 public 端点；失败回退硬编码（frontend-api §2.2 空态，同侧栏口径） -->
      <div class="login-brand">
        <img src="../assets/workbench/hospital_logo.png" alt="院徽" class="brand-logo" />
        <h1 class="brand-name">{{ hospital.name }}</h1>
        <p class="brand-sub">{{ hospital.english_name }}</p>
      </div>

      <div class="login-divider"></div>
      <p class="login-caption">院长查询与决策支持系统</p>

      <form class="login-form" novalidate @submit.prevent="onSubmit">
        <div class="field" :class="{ 'is-error': fieldErrors.username }">
          <label class="field-label" for="login-username">用户名</label>
          <input
            id="login-username"
            v-model.trim="username"
            class="field-input"
            type="text"
            placeholder="请输入登录名"
            autocomplete="username"
          />
          <p v-if="fieldErrors.username" class="field-error">{{ fieldErrors.username }}</p>
        </div>

        <div class="field" :class="{ 'is-error': fieldErrors.password }">
          <label class="field-label" for="login-password">口令</label>
          <input
            id="login-password"
            v-model="password"
            class="field-input"
            type="password"
            placeholder="请输入口令"
            autocomplete="current-password"
          />
          <p v-if="fieldErrors.password" class="field-error">{{ fieldErrors.password }}</p>
        </div>

        <!-- 20101 内联 / 20102 停用 / 20104 锁定 / 其余——message 直渲（error-codes §4） -->
        <p v-if="formError" class="form-error" role="alert">{{ formError }}</p>

        <button class="login-btn" type="submit" :disabled="submitting">
          {{ submitting ? '登录中…' : '登 录' }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getHospitalProfile, login, type LoginError } from '../api/auth'
import type { HospitalProfileResp } from '../api/types'

const route = useRoute()
const router = useRouter()

const hospital = ref<HospitalProfileResp>({
  name: 'XX市人民医院',
  english_name: "PEOPLE'S HOSPITAL",
  level: '',
  motto: [],
  slogans: [],
  pillars: [],
})

const username = ref('')
const password = ref('')
const submitting = ref(false)
const fieldErrors = ref<Record<string, string>>({})
const formError = ref('')

onMounted(async () => {
  hospital.value = (await getHospitalProfile().catch(() => null)) ?? hospital.value
})

const onSubmit = async () => {
  if (submitting.value) return
  fieldErrors.value = {}
  formError.value = ''
  // 本地必填前置（键位对齐契约 §2.3 10001 data.fields），省一次注定失败的往返
  if (!username.value || !password.value) {
    fieldErrors.value = {
      ...(username.value ? {} : { username: '请输入登录名' }),
      ...(password.value ? {} : { password: '请输入口令' }),
    }
    return
  }
  submitting.value = true
  try {
    await login(username.value, password.value)
    // 仅接受站内路径，挡 //外站 开放重定向
    const r = route.query.redirect
    const target =
      typeof r === 'string' && r.startsWith('/') && !r.startsWith('//') ? r : '/workbench'
    router.replace(target)
  } catch (err) {
    const e = err as LoginError
    if (e.code === 10001 && e.fields) {
      fieldErrors.value = e.fields
    } else {
      formError.value = e.message || '登录失败，请稍后重试'
    }
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
/* .auth-layout：design-tokens §6 R8 登录页 L1 作用域，直接消费 --wb-*（tokens.css 已登记） */
.auth-layout {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--wb-bg);
  font-family: var(--p-font-base);
  color: var(--wb-text-1);
  padding: var(--wb-space-4);
}

.login-card {
  width: 380px;
  background: var(--wb-surface);
  border: 1px solid var(--wb-border);
  border-radius: var(--wb-radius-card);
  box-shadow: var(--wb-shadow-hover);
  padding: calc(var(--wb-space-5) + var(--wb-space-2)) calc(var(--wb-space-5) + var(--wb-space-3));
}

.login-brand {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--wb-space-1);
}

.brand-logo {
  width: 48px;
  height: 48px;
  border-radius: var(--wb-radius-pill);
  margin-bottom: var(--wb-space-1);
}

.brand-name {
  font-size: var(--wb-fs-xl);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  letter-spacing: var(--wb-ls-lg);
  line-height: var(--wb-lh-snug);
}

.brand-sub {
  font-size: var(--wb-fs-xs);
  font-weight: var(--wb-fw-semibold);
  color: var(--wb-text-3);
  letter-spacing: var(--wb-ls-xl);
}

.login-divider {
  height: 1px;
  background: var(--wb-hairline);
  margin: var(--wb-space-4) 0;
}

.login-caption {
  font-size: var(--wb-fs-md);
  color: var(--wb-text-3);
  text-align: center;
  letter-spacing: var(--wb-ls-md);
  margin-bottom: var(--wb-space-4);
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: var(--wb-space-3);
}

.field-label {
  display: block;
  font-size: var(--wb-fs-sm);
  font-weight: var(--wb-fw-medium);
  color: var(--wb-text-2);
  margin-bottom: var(--wb-space-1);
}

.field-input {
  width: 100%;
  height: 36px;
  border: 1px solid var(--wb-input-border);
  border-radius: var(--wb-radius-inner);
  background: var(--wb-surface);
  padding-inline: var(--wb-space-3);
  font-family: inherit;
  font-size: var(--wb-fs-md);
  color: var(--wb-text-1);
  outline: none;
  user-select: text;
  transition: border-color var(--wb-dur-fast);
}

.field-input::placeholder {
  color: var(--wb-text-4);
}

.field-input:focus {
  border-color: var(--wb-accent);
}

.field.is-error .field-input {
  border-color: var(--wb-red);
}

.field-error {
  font-size: var(--wb-fs-xs);
  color: var(--wb-red);
  margin-top: var(--wb-space-1);
  line-height: var(--wb-lh-compact);
}

.form-error {
  background: var(--wb-tag-red-bg);
  color: var(--wb-red);
  font-size: var(--wb-fs-sm);
  line-height: var(--wb-lh-normal);
  border-radius: var(--wb-radius-tag);
  padding: var(--wb-space-2) var(--wb-space-3);
}

.login-btn {
  width: 100%;
  height: 38px;
  border: none;
  border-radius: var(--wb-radius-inner);
  background: var(--wb-accent);
  color: var(--p-white); /* 原色直取 */
  font-family: inherit;
  font-size: var(--wb-fs-lg);
  font-weight: var(--wb-fw-semibold);
  letter-spacing: var(--wb-ls-2xl);
  cursor: pointer;
  transition: background var(--wb-dur-fast);
}

.login-btn:hover:not(:disabled) {
  background: var(--wb-primary);
}

.login-btn:disabled {
  opacity: var(--wb-opacity-muted);
  cursor: not-allowed;
}
</style>
