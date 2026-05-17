# 🚀 AVE (ABAP Versions Explorer) Wiki

Ласкаво просимо до документації проекту AVE — комплексного інструменту для探索, порівняння та аналізу версій ABAP об'єктів у SAP системах.

## 📋 Основна інформація

- **Назва**: ABAP Versions Explorer (AVE)
- **Тип**: SAP GUI ABAP Program з GUI інтерфейсом
- **Мова**: ABAP (Clean ABAP стиль)
- **Основна функціональність**: 
  - 🔍 Перегляд історії версій об'єктів
  - 📊 Порівняння версій (diff)
  - ✅ Код-ревю з можливістю затвердження
  - 📈 Статистика змін
  - 🏷️ Підтримка різних типів об'єктів

## 🎯 Підтримувані об'єкти

- ✅ Programs/Includes (REPS)
- ✅ ABAP Classes (CLAS) з методами (METH)
- ✅ Function Modules (FUNC)
- ✅ Interfaces (INTF)
- ✅ CDS DDL Sources (DDLS)
- ✅ Transport Requests/Tasks (TR)
- ✅ Development Packages (DEVC)

## 🏗️ Архітектура

AVE організована за шарами функціональності:

1. **[[layers/object-handler-layer]]** — обробка вхідних об'єктів
2. **[[layers/version-layer]]** — управління версіями та метаданими
3. **[[layers/diff-render-layer]]** — обчислення дифів і рендеринг
4. **[[layers/popup-ui-layer]]** — SAP GUI інтерфейс
5. **[[layers/code-review-layer]]** — система код-ревю

## 📚 Основні класи

### Ядро проекту
- [[classes/zcl_ave_popup|Main Popup]] — основний UI контролер
- [[classes/zcl_ave_object_factory|Object Factory]] — фабрика для об'єктів
- [[classes/zcl_ave_popup_diff|Diff Engine]] — розрахунок дифів

### Обробка об'єктів
- [[classes/zcl_ave_object_prog|Program Handler]]
- [[classes/zcl_ave_object_clas|Class Handler]]
- [[classes/zcl_ave_object_func|Function Module Handler]]
- [[classes/zcl_ave_object_ddls|DDLS Handler]]
- [[classes/zcl_ave_object_tr|Transport Request Handler]]

### Версії і сирцеві дані
- [[classes/zcl_ave_version|Version]] — одна версія об'єкта
- [[classes/zcl_ave_vrsd|VRSD Manager]] — управління метаданими версій
- [[classes/zcl_ave_request|Request Manager]] — управління TR/tasks

### Код-ревю
- [[classes/zcl_ave_acr_state|Review State]] — стан ревю
- [[classes/zcl_ave_acr_renderer|Review Renderer]] — рендеринг ревю
- [[classes/zcl_ave_acr_stats|Review Stats]] — статистика

## 🔗 Інтерфейси

- [[classes/zif_ave_object|Object Interface]] — контракт для обробників об'єктів
- [[classes/zif_ave_popup_types|Popup Types]] — типи для diff/版本 операцій
- [[classes/zif_ave_acr_types|Code Review Types]] — типи для ревю

## ⚙️ Утиліти

- [[classes/zcl_ave_author|Author Resolver]] — розпізнавання користувачів
- [[classes/zcl_ave_versno|Version Number Converter]] — конвертація версій
- [[classes/zcl_ave_progress|Progress Tracker]] — індикатор прогресу

## 🚀 Як розпочати

### Вхідна точка
- **Program**: `Z_AVE` — экран вибору та bootstrap

### Генерація standalone версії
```bash
# Linux/Mac
bash generate_standalone.sh

# Windows
generate_standalone.bat
```

Використовує `abapmerge` для об'єднання всіх файлів у один виконуваний файл.

## 🔄 Типовий workflow

```
User Input (Object Type + Name)
         ↓
Object Factory resolves to Handler
         ↓
Handler extracts versionable Parts
         ↓
VRSD Manager loads Version metadata
         ↓
Version Manager loads Source code
         ↓
Popup displays interactive UI
         ↓
User selects versions for comparison
         ↓
Diff Engine computes differences
         ↓
HTML Renderer displays result
         ↓
Optional: Code Review workflow
```

## 📊 Основні поняття

### Versionable Parts
Об'єкт може мати кілька "частин", які версіюються окремо:
- Program = 1 part (REPS)
- Class = multiple parts (sections, local includes, methods, test include)
- Function Module = 1 part (FUNC)
- Interface = 1 part (generated include)

### Version Directory (VRSD)
Таблиця SAP, яка містить метаінформацію про версії об'єктів:
- Version number, date, author, description
- Transport request/task інформація
- Status (released/unreleased)

### Diff Operations
- `INSERT`: нові рядки
- `DELETE`: видалені рядки
- `REPLACE`: змінені рядки
- `KEEP`: незмінені рядки

## 🎓 Для розробників

- Використовуй [[layers/object-handler-layer]] щоб додати новий тип об'єкта
- Див [[layers/diff-render-layer]] для розуміння алгоритму дифу
- [[layers/code-review-layer]] для функціоналу ревю

## 📝 Нотатки розробника

- **DO NOT EDIT**: `z_ave_standalone.prog.abap` — це автогенерований файл
- **DO REGENERATE** після змін у вихідних файлах: запусти `generate_standalone.sh`
- Всі класи мають префікс `ZCL_AVE_`, інтерфейси — `ZIF_AVE_`
- Винятки: `ZCX_AVE`

## 🔗 Дополнительные ресурсы

- [[architecture|Детальна архітектура]]
- [GitHub Repository](https://github.com/larshp/abapmerge) — abapmerge tool
- SAP ABAP документація

---

**Last Updated**: 2026-05-17 | **Language**: Українська/English