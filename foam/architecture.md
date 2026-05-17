# 🏗️ Архітектура AVE

## Огляд системи

AVE розташована на **5 основних архітектурних шарах**, організованих за функціональністю:

```
┌─────────────────────────────────────────┐
│     UI Layer (Popup / SAP GUI)         │  ← zcl_ave_popup
├─────────────────────────────────────────┤
│   Diff/Render Layer (HTML/Compare)     │  ← zcl_ave_popup_diff, zcl_ave_popup_html
├─────────────────────────────────────────┤
│   Version Layer (Metadata/Source)      │  ← zcl_ave_version, zcl_ave_vrsd
├─────────────────────────────────────────┤
│   Object Handler Layer (Parts)         │  ← zcl_ave_object_*
├─────────────────────────────────────────┤
│   SAP Kernel (ABAP Runtime)            │  ← ABAP API, VRSD, SVRS, E070
└─────────────────────────────────────────┘
```

## Детальне описання шарів

### 1. Object Handler Layer 📦

**Відповідність**: Перетворення логічного вхідного об'єкта на **вersionable parts**.

Кожен тип об'єкта має власну реалізацію:

| Клас | Об'єкт | Частини |
|------|--------|---------|
| [[zcl_ave_object_prog]] | Program/Include | 1 × REPS (源代码) |
| [[zcl_ave_object_clas]] | ABAP Class | ~N × (sections, includes, METH methods) |
| [[zcl_ave_object_func]] | Function Module | 1 × FUNC |
| [[zcl_ave_object_ddls]] | CDS DDL Source | 1 × DDLS |
| [[zcl_ave_object_intf]] | Interface | 1 × generated REPS |
| [[zcl_ave_object_tr]] | Transport Request | N × nested objects |
| [[zcl_ave_object_pack]] | Package | N × nested objects |

**Factory**: [[zcl_ave_object_factory]] — вибір правильної реалізації

**Interface**: [[zif_ave_object]] — контракт для всіх обробників

### 2. Version Layer 📚

**Відповідність**: Управління метаданими версій і завантаження сирцевого кода.

- **[[zcl_ave_vrsd]]** — завантажує записи метаданих VRSD з бази та SVRS API
- **[[zcl_ave_version]]** — одна версія об'єкта (метадані + сирцевий код)
- **[[zcl_ave_version2]]** — альтернативний завантажувач на базі SVRS_GET_VERSION_LOCAL/REMOTE
- **[[zcl_ave_request]]** — управління TR/task інформацією з E070/E071

**Основні операції**:
- Завантажити VRSD (metadata) для об'єкта
- Зберегти "активну" та "змінену" версії як синтетичні записи
- Завантажити сирцевий код для кожної версії
- Знайти TR/task, відповідальний за версію

### 3. Diff/Render Layer 🎨

**Відповідність**: Обчислення розходжень і рендеринг результатів у HTML.

- **[[zcl_ave_popup_diff]]** — engine для обчислення line-level LCS diff, inline character diff, blame map
- **[[zcl_ave_popup_html]]** — рендеринг HTML (один панель, два панелі, компактний режим)
- **[[zcl_ave_popup_data]]** — допоміжні функції для версій і типів об'єктів

**Алгоритми**:
- **LCS** (Longest Common Subsequence) для лінійного дифу з оптимізацією памяті
- **Character-level diff** для inline змін
- **Blame map** — відстеження авторства доданих/видалених рядків

### 4. Popup/UI Layer 🖥️

**Відповідність**: SAP GUI інтерфейс — сплітери, ALV грид, HTML viewer.

- **[[zcl_ave_popup]]** — основний контролер
  - Побудова layout (containers, splitters)
  - ALV сітки для частин і версій
  - HTML viewer для дифу/кода
  - Обробка користувальницьких команд

**UI Компоненти**:
- Parts ALV grid — список вersionable частин
- Versions ALV grid — список версій для обраної частини
- HTML viewer — дисплей дифу/кода
- Toolbar — команди (Diff, Source, Review, тощо)

### 5. Code Review Layer ✅

**Відповідність**: Система код-ревю з затвердженням/відхиленням, статистикою, збереженням.

**Компоненти**:
- **[[zcl_ave_acr_state]]** — стан ревю (затверджено/відхилено hunks)
- **[[zcl_ave_acr_renderer]]** — рендеринг UI для ревю
- **[[zcl_ave_acr_stats]]** — обчислення статистики (insertions, deletions, hunks)
- **[[zcl_ave_acr_report]]** — HTML звіт ревю
- **[[zcl_ave_acr_repository]]** — персистентність у таблиці ZAVE_REVIEW

**Workflow**:
1. User вибирає об'єкти для ревю
2. AVE передобчислює дифи для всіх частин
3. User проглядає дифи, затверджує/відхиляє hunk'и
4. Результати зберігаються у DB (ZAVE_REVIEW)
5. Генерується звіт зі статистикою

## Потоки даних

### Типовий сценарій: Перегляд версій

```
1. User вводить Object Type + Name
   ↓
2. Object Factory → get_instance() → створює відповідний Handler
   ↓
3. Handler → get_parts() → список versionable частин
   ↓
4. VRSD Manager завантажує метадані версій для кожної частини
   ↓
5. Popup відображає:
   - Parts ALV grid (ліва сторона)
   - Versions ALV grid (внизу)
   - HTML viewer (права сторона — порожня поки не вибрано версій)
   ↓
6. User вибирає дві версії для порівняння
   ↓
7. Version Manager завантажує сирцевий код для обох версій
   ↓
8. Diff Engine обчислює розходження
   ↓
9. HTML Renderer створює HTML сторінку з дифом
   ↓
10. HTML Viewer відображає результат
```

### Код-ревю сценарій

```
1. User вибирає "Prepare Code Review" для TR
   ↓
2. ACR State завантажує/ініціалізує стан ревю
   ↓
3. Для кожної частини:
   - Завантажує версії (обраного + попередньої)
   - Обчислює дифи (Diff Engine)
   - Визначає hunks (групи змін)
   ↓
4. ACR Stats обчислює інформацію про добавлення/вилучення
   ↓
5. ACR Renderer вставляє UI контрольні елементи (approve/decline buttons)
   ↓
6. Popup рендерує інтерактивний звіт
   ↓
7. User затверджує/відхиляє hunks, додає коментарі
   ↓
8. ACR Repository зберігає результати у ZAVE_REVIEW
   ↓
9. ACR Report генерує підсумковий HTML звіт
```

## Ключові дизайнерські рішення

### 1. Handler Pattern
Кожен тип об'єкта має окремий handler, що реалізує [[zif_ave_object]] контракт. Дозволяє додавати нові типи без змін у ядрі.

### 2. Part-Based Versioning
Об'єкт розбивається на **parts** (наприклад, класс → методи), кожна part версіюється окремо. Це дозволяє порівнювати окремі методи.

### 3. Low-Memory Diff Algorithm
LCS diff використовує look-ahead оптимізацію для великих файлів без повного завантаження у памяті.

### 4. Synthetic Versions
"Active" та "Modified" версії синтезуються як pseudo-VRSD записи, щоб користувачу показувати поточний стан.

### 5. HTML as Presentation
Весь дисплей — HTML у SAP GUI HTML viewer. Дозволяє гнучкий рендеринг і interactive UI.

## Залежності

```
┌─────────────────────────────────────┐
│       z_ave.prog.abap               │  ← Entry point
│   (Selection screen + bootstrap)    │
└──────────────┬──────────────────────┘
               │
               ↓
         zcl_ave_popup ────────────────────┐
         (Main controller)                  │
               ├──→ zcl_ave_object_factory  │
               │    (Object handlers)       │
               │                            │
               ├──→ zcl_ave_popup_diff      │ Diff & Rendering
               │    zcl_ave_popup_html      │
               │    zcl_ave_popup_data      │
               │                            │
               ├──→ zcl_ave_vrsd            │ Versions
               │    zcl_ave_version         │
               │    zcl_ave_version2        │
               │    zcl_ave_request         │
               │                            │
               └──→ zcl_ave_acr_* ─────────┘ Code Review
                    (Review classes)

Utilities (used everywhere):
  ├─ zcl_ave_author (user name resolution)
  ├─ zcl_ave_versno (version number conversion)
  ├─ zcl_ave_progress (progress indicator)
  ├─ zcx_ave (exception handling)
  └─ Interfaces: zif_ave_object, zif_ave_popup_types, zif_ave_acr_types
```

## Рекомендації для розробників

### Додання нового типу об'єкта
1. Створи новий клас `zcl_ave_object_XXXX` що реалізує [[zif_ave_object]]
2. Додай обробку у [[zcl_ave_object_factory]]
3. Тестуй через z_ave.prog.abap

### Модифікація diff алгоритму
1. Змінюй [[zcl_ave_popup_diff]]
2. **ОБОВ'ЯЗКОВО** синхронізуй з `html_simulator/diff.js`
3. Тестуй обидва варіанти (ABAP + JavaScript)

### Розширення код-ревю функціоналу
1. Почни з [[zcl_ave_acr_state]] для нового стану
2. Додай рендеринг у [[zcl_ave_acr_renderer]]
3. Оновлення персистентності у [[zcl_ave_acr_repository]]

---

**Last Updated**: 2026-05-17