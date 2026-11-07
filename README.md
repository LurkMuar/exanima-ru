# Exanima — русификация текста для текущей версии игры

Набор скриптов, который адаптирует русификатор **ZoG Forum Team v1.3.2** (сделан под игру v0.8.3d)
к текущей версии Exanima и дополняет перевод новых строк.

> ⚠️ Репозиторий **не содержит** файлов игры и файлов русификатора ZoG.
> Их нужно взять самостоятельно (см. «Что понадобится»). Здесь только скрипты и собственный перевод.

Проверено на: **Exanima 0.9.5.2g (Steam)**

Автор: [LurkMuar](https://github.com/LurkMuar)

## Статус

| Часть | Состояние |
|---|---|
| Предметы, записки, книги, письма (`Resource.rpk`) | ✅ переведено (старый перевод ZoG + новые строки) |
| Кириллические шрифты в `Exanima.exe` | ✅ работают |
| Интерфейс и меню (текст внутри `Exanima.exe`) | ❌ на английском — старый парсер ZoG не находит текст в новом exe |
| Описания сил школы Force (`pwr_force.pwr`) | ❌ на английском — парсер ZoG падает на новом формате |
| Шрифт заголовков главного меню (`titlefont`) | ⚪ оригинальный |

### Известные проблемы

- Изредка экран моргает чёрным (замечено при наведении на предметы). Причина не выяснена.
- Шрифты ZoG — пиксельные, отличаются по стилю от оригинальных.
- Лишний промежуток после некоторых латинских букв (`I`, `W`) в интерфейсе.
- Плейсхолдеры `{®Exanima.Unknown.HeShe}` и т.п. подставляют английские местоимения, пока не переведён exe.

## Что понадобится

1. Exanima (Steam).
2. Установщик русификатора **ZoG Forum Team v1.3.2** (PlayGround, раздел файлов Exanima).
3. [innoextract](https://constexpr.org/innoextract/) — распаковать установщик без запуска.
4. Windows PowerShell 5.
5. *(необязательно, только для перевода новых строк)* LM Studio + модель `ai-sage/GigaChat3.1-10B-A1.8B-GGUF` (Q8_0).

## Структура рабочей папки

Скрипты по умолчанию работают с `D:\exanima-ru` (параметр `-Root`) и игрой в
`D:\SteamLibrary\steamapps\common\Exanima` (параметр `-Game`).

```
D:\exanima-ru\
├── backup\        чистые Exanima.exe и Resource.rpk (копия из игры, не трогать)
├── game\          рабочие копии Exanima.exe и Resource.rpk
│   └── patcher\   содержимое app\patcher из установщика ZoG
├── steam-original\ создаётся install.ps1 — для отката
└── <этот репозиторий>
```

## Сборка

```powershell
# 0. Подготовка
mkdir D:\exanima-ru\backup, D:\exanima-ru\game
$g = "D:\SteamLibrary\steamapps\common\Exanima"
Copy-Item "$g\Exanima.exe", "$g\Resource.rpk" D:\exanima-ru\backup\
Copy-Item "$g\Exanima.exe", "$g\Resource.rpk" D:\exanima-ru\game\
innoextract.exe -d D:\exanima-ru\extracted <установщик ZoG>.exe
Copy-Item D:\exanima-ru\extracted\app\patcher D:\exanima-ru\game\patcher -Recurse

# 1. Восстановить заголовки утилит ZoG (они специально «спрятаны»)
powershell -ExecutionPolicy Bypass -File .\scripts\00_unhide_tools.ps1

# 2. Извлечь текст и сопоставить со старым переводом
Copy-Item .\patcher\extract.bat D:\exanima-ru\game\patcher\
cmd /c "D:\exanima-ru\game\patcher\extract.bat < nul > D:\exanima-ru\game\patcher\extract.log 2>&1"

# 3. Точные совпадения со старым переводом
powershell -ExecutionPolicy Bypass -File .\scripts\stage1.ps1

# 4. Сборка: текст -> Resource.rpk -> шрифты -> установка в игру
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

Переводы новых строк уже лежат в `data/` — шаг с моделью не обязателен.
Чтобы перевести новые строки самому (например, после обновления игры):
запусти LM Studio, затем `scripts\stage2.ps1` и в `build.ps1` / `stage3.ps1` укажи
`-Stage2 D:\exanima-ru\game\patcher\results_stage2.tsv`.

### Откат

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Restore
```

Или Steam → Exanima → Свойства → Установленные файлы → Проверить целостность.

## Как это устроено

- **Текст.** Утилиты ZoG извлекают строки из `Resource.rpk` в построчный `resource.txt`.
  `stage1` подставляет точные совпадения из старого перевода ZoG по всему файлу (утилита ZoG ищет
  только внутри того же блока), `stage2` переводит остаток локальной моделью с глоссарием, образцами
  из старого перевода и проверкой служебных меток, `stage3` собирает итог с ручными правками
  (`data/overrides.tsv`) поверх. Файл сохраняется в Windows-1251.
- **Шрифты.** В текущей версии exe перед шрифтами появились три новые картинки, и утилита ZoG вставляла
  шрифты не туда. `fonts_patch.ps1` кладёт `Exanima_8…12.rfi` ровно в ресурсы `RAYFORM06R…16R_RFI`
  и правит их размер в таблице ресурсов.
- **Таблица глифов.** Записи таблицы выросли с 588 до 608 байт, поэтому таблицу ZoG целиком вставлять
  нельзя (весь текст пропадает). Скрипт берёт оригинальную таблицу и переносит в неё данные символов
  ZoG по записям. `-SpacingLatin` / `-SpacingCyr` добавляют ширину латинским / русским буквам.
- **`titlefont.rfi` от ZoG не используется:** в нём латинские заглавные перерисованы под кириллицу
  (см. `tools\translit.txt`), и английское меню превращается в набор русских букв.

Смещения в exe привязаны к конкретной сборке игры. Скрипт проверяет их перед записью и
остановится, если игра обновилась. Найти новые: `scripts\pe_res.ps1`.

## Благодарности

- **ZoG Forum Team** — русификатор Exanima: перевод *Denis_ma, DragonZH*, техническая часть и шрифты
  *DragonZH*. Без их перевода, шрифтов и инструментов этого проекта бы не было.
- **Bare Mettle Entertainment** — за Exanima.
