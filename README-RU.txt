KIROKU — fixed community build

ЧТО ВНУТРИ
- index.html — рабочая версия KIROKU с сохранённой цветовой системой Midnight / Sakura / Forest / Ember.
- images/ — изображения Naoya для главной страницы.
- KIROKU-LAB-MIGRATION.sql — миграция Supabase: приватные Lab-данные, публичные community-доски и переключатели приватности.

ВАЖНО
1. Original (чёрно-белый сайт) и архив с превью не изменялись. index(3).html использовался только как источник идей.
2. Перед заменой файла на GitHub сделай commit текущего index.html как резервную копию.
3. Не удаляй папку images/ — там нужные изображения.
4. В Supabase SQL Editor один раз запусти KIROKU-LAB-MIGRATION.sql.
   Миграция добавляет share_anime / share_tiers / share_trophies в profiles,
   RPC kiroku_set_sharing, политику просмотра профилей и anime-листов,
   а также view kiroku_public_lab с маскировкой закрытых данных.
5. Существующие таблицы profiles, anime_catalog и user_anime не пересоздаются и не удаляются.
6. Supabase-проект уже прописан в index.html: URL и publishable key менять не нужно.

ВХОД И РЕГИСТРАЦИЯ
- Старый вход по username+password удалён.
- Вход только по email + password через Supabase Auth.
- Регистрация: кнопка «Create account» → публичный username, email, password (минимум 8 символов).
- Если в Supabase включено подтверждение email, после регистрации нужно открыть ссылку из письма.
- Пользователей-друзей добавляй напрямую в Supabase Authentication (email + password) или через форму регистрации на сайте.
- Existing owner-аккаунт ilyosbek0088@gmail.com продолжает работать как раньше.
- Восстановление пароля работает через обычный Supabase Reset Password для реальных email-адресов.

ПУБЛИКАЦИЯ И ПРИВАТНОСТЬ
- В Premium → Sharing & privacy три переключателя:
  - Anime ranking — виден в разделе Friends’ archives;
  - Character tierlists — виден в Community boards;
  - Achievements — видны рядом с профилем в Community.
- По умолчанию всё включено. Любой переключатель можно выключить — данные сразу исчезнут из чужих разделов.
- Свои личные tierlists, статистика и трофеи всегда остаются доступны только владельцу;
  community-view отдаёт чужие tiers/trophies только если владелец их открыл.
- Раздел Community (Features) показывает список участников, их character tierlist и ачивки.
- Friends’ archives и Currently watching обновляются в realtime.

ЧТО ДОБАВЛЕНО / ИСПРАВЛЕНО
- Character tierlists: темы, S/A/B/C/D/Unranked, добавление/редактирование/удаление персонажей.
- Drag-and-drop на компьютере; на тач-устройствах — тап по персонажу, затем тап по тиру (повторный тап по персонажу открывает редактор).
- Поиск портретов через AniList → Jikan → локальный кэш.
- Anime Duel с Elo-подобным рейтингом и Smart Roll: completed/dropped по умолчанию исключены, есть фильтры статусов, «только избранное» и «без повторов».
- Экспорт Top 5 и character tierlist в PNG; для постеров без CORS есть proxy-fallback.
- Постеры теперь восстанавливаются по названию и на чужих карточках; поиск персонажей умеет искать villain/alias fallback.
- Улучшена раскладка на маленьких ноутбуках: кнопки не слипаются, login-карточка компактнее на низких экранах.
- Unranked теперь попадает в экспорт tierlist-изображения.
- Импорт/экспорт JSON включает anime list, character boards, stats и trophies.
- Асинхронная запись в Supabase с очередью: ошибки sync больше не дают ложный «успех».
- Состояние авторизации отслеживается через onAuthStateChange; вход/выход синхронизируется между вкладками.
- Realtime-каналы закрываются при logout; фильтры сокращают лишние события.
- Улучшены @media-правила для 860px и 520px, фокус-стили и анимация модалок.

ПРОВЕРКИ
- JavaScript syntax check: пройден.
- CSS parser check: пройден.
- Проверка повторяющихся HTML id: дубликатов нет.
- Проверка ссылок на элементы по literal $("id"): отсутствующих id нет.
- Реальный вход, регистрация, SQL-миграция и Realtime против живого Supabase в этой среде не запускались — проверь их после загрузки SQL на сайте.
