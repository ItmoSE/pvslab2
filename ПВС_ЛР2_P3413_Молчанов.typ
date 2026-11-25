#set document(title: "Лабораторная работа № 2. Последовательный интерфейс UART", author: "Молчанов Федор Денисович")
#set page(
  paper: "a4",
  margin: (x: 20mm, y: 18mm),
  footer: align(center)[г. Санкт-Петербург 2026],
)
#set text(size: 10pt, lang: "ru")
#set par(justify: true, leading: 0.7em)

// Титульный лист.

#v(1.6cm)

#align(center)[
  Федеральное государственное автономное образовательное
  #linebreak()
  учреждение высшего образования
  #linebreak()
  «Национальный исследовательский университет ИТМО»
]

#v(3.7cm)

#align(center)[
  #text(weight: "bold")[Отчёт]
  #linebreak()
  #text(weight: "bold")[По лабораторной работе № 2]
  #linebreak()
  по дисциплине Проектирование Вычислительных Систем
  #linebreak()
  #text(weight: "bold")[Вариант: -]
]

#v(6.9cm)

#align(right)[
  Работу выполнил:
  #linebreak()
  Молчанов Федор Денисович P3413
  #linebreak()
  #linebreak()
  Работу принял:
  #linebreak()
  Пинкевич Василий Юрьевич
]

#v(2cm)

#pagebreak()
#set page(
  margin: (left: 25mm, right: 20mm, top: 20mm, bottom: 20mm),
  footer: context {
    align(center)[
      #counter(page).display("1")
    ]
  },
)
#counter(page).update(1)

// Оформление основной части сохранено из исходного отчёта.
#set text(font: ("Times New Roman", "Liberation Serif", "DejaVu Serif"), size: 12pt, lang: "ru", fill: black)
#set par(justify: true, leading: 0.5em, first-line-indent: 1.25cm)
#set heading(numbering: "1.1")
#show heading: set text(size: 12pt, weight: "bold")
#show heading.where(level: 1): set block(above: 1.3em, below: 0.8em)
#show link: set text(fill: black)
#show raw: set text(font: ("DejaVu Sans Mono", "Liberation Mono"), size: 8.5pt, fill: black)
#show raw.where(block: true): it => block(width: 100%, breakable: true, inset: (y: 4pt))[
  #set par(justify: false, first-line-indent: 0pt, leading: 0.3em)
  #it
]
#show figure: set par(first-line-indent: 0pt)
#show figure.where(kind: table): set text(size: 11pt)
#set table(inset: 5pt, stroke: 0.5pt)
#show table: set par(justify: false, first-line-indent: 0pt, leading: 0.25em)
#let node(body) = block(width: 100%, inset: 5pt, stroke: 0.6pt, radius: 2pt)[#align(center, body)]
#let arrow = align(center)[↓]
#let listing(title, code) = [
  #block(breakable: false)[*#title*]
  #raw(code, lang: "c", block: true)
]


#outline(title: [Оглавление], depth: 3, indent: 1.35em)
#pagebreak()

= Цель и задание

Цели работы — изучить последовательный интерфейс UART, организацию аппаратных прерываний STM32 и принципы работы приемопередатчика USART; получить навыки реализации обмена данными в режимах опроса и прерываний.

В первой части требуется разработать два варианта драйвера UART на базе HAL. Приём в режиме опроса должен быть неблокирующим; в режиме прерываний неблокирующими должны быть приём и передача, с использованием универсальных очередей настраиваемого при компиляции размера. В режиме опроса прерывания соответствующего USART должны быть запрещены. Прикладная программа должна возвращать эхо, ответы на команды и сообщение о неизвестной команде.

Вариант 1 предусматривает доработку светофора из лабораторной работы № 1: включение и отключение реакции на кнопку, изменение длительности красной фазы и управление режимом UART. Скорость обмена — 57600 бит/с. Команды приведены в @tab-commands.

#figure(
  table(
    columns: (1.4fr, 2fr),
    table.header([*Команда*], [*Назначение*]),
    [`?`], [Текущая фаза (`red`, `yellow`, `green`, `blinking green`), режим кнопки, тайм-аут и символ `I` или `P`.],
    [`set mode 1`], [Учитывать нажатия кнопки.],
    [`set mode 2`], [Игнорировать нажатия кнопки.],
    [`set timeout X`], [Установить длительность красной фазы в секундах.],
    [`set interrupts on`], [Перейти в режим прерываний.],
    [`set interrupts off`], [Перейти в режим опроса.],
  ),
  caption: [Команды варианта 1],
) <tab-commands>

Во второй части выбран способ 2: разработка программного симулятора стенда, взаимодействующего с клиентом через виртуальный последовательный порт. Моделирование регистров и реализация двух аппаратных режимов UART в симуляторе не требуются.

= Аппаратная конфигурация и инструменты

Вместо упомянутого в методических указаниях стенда SDK-1.1M использовалась плата STM32F746G-DISCO с микроконтроллером STM32F746NGH6 (ядро Arm Cortex-M7). Проект сформирован средствами STM32CubeMX, сборка выполнялась с помощью CMake и GNU Arm Embedded Toolchain в Arch Linux. Для редактирования использовались Neovim и clangd, для загрузки прошивки — OpenOCD, для последовательного обмена — picocom.

== Настройка USART

Для обмена с компьютером использован USART1, подключённый к виртуальному COM-порту встроенного ST-LINK. В @tab-config приведены параметры конфигурации. Сигналы SWD используются для прошивки и отладки, а сигналы TX/RX — для последовательного обмена; это разные интерфейсы.

#figure(
  table(
    columns: (1fr, 1.5fr),
    table.header([*Параметр*], [*Значение*]),
    [МК], [STM32F746NGH6],
    [Источник SYSCLK], [HSI, 16 МГц; PLL не используется],
    [AHB, APB1, APB2], [Делители 1; частота 16 МГц],
    [USART1], [Asynchronous; тактирование от PCLK2],
    [TX], [PA9, AF7],
    [RX], [PB7, AF7],
    [Скорость], [57600 бит/с],
    [Формат кадра], [8 бит данных, без чётности, 1 стоповый бит (8N1)],
    [Управление потоком], [Нет],
    [NVIC], [USART1 global interrupt; разрешение управляется драйвером],
    [SYS], [Serial Wire; SysTick, 1 мс],
  ),
  caption: [Параметры микроконтроллера и USART1],
) <tab-config>

Линии PA9 и PB7 связаны с UART встроенного ST-LINK, который предоставляет операционной системе виртуальный последовательный порт. На Linux при выполнении работы использовался `/dev/ttyACM0`. Схема соединений представлена на @fig-connection.

#figure(
  block(width: 100%)[
    #node[ПК: picocom, `/dev/ttyACM0`]
    #align(center)[↕ USB]
    #node[ST-LINK: Virtual COM Port]
    #align(center)[↕ TX/RX, 57600 8N1]
    #node[STM32F746: USART1 — PA9 / PB7]
    #align(center)[↕]
    #node[UART-драйвер и прикладная программа]
  ],
  caption: [Соединение терминала с микроконтроллером],
) <fig-connection>

Для светофора переиспользована подсистема GPIO предыдущей работы: красный и жёлтый светодиоды на PG6 и PG7, зелёный светодиод на PI1, кнопка на PI11. Собственные модули GPIO, светодиодов и кнопки перенесены без изменения принципа работы. Функции инициализации GPIO из предыдущей работы сохранены.

== Принцип работы UART и прерываний

UART передаёт данные последовательно, без общей линии тактирования. В формате 8N1 кадр состоит из стартового бита, восьми информационных битов и стопового бита. При 57600 бит/с длительность кадра составляет приблизительно 174 мкс. Сдвиговый регистр приёмника собирает кадр, после чего аппаратно обновляется RDR. Передатчик переносит значение из TDR в сдвиговый регистр, который отправляет кадр на линию TX.

Регистр ISR содержит флаги состояния: RXNE (Receive Data Register Not Empty) означает наличие непрочитанных данных; TXE (Transmit Data Register Empty) — готовность TDR принять новые данные; TC (Transmission Complete) — завершение передачи последнего кадра. В CR1 располагаются биты разрешения соответствующих прерываний: RXNEIE, TXEIE, TCIE. Упрощённое формирование запроса показано на @fig-irq.

#figure(
  block(width: 100%)[
    #grid(
      columns: (1fr, 1fr, 1fr),
      gutter: 6pt,
      node[`RXNE` ∧ `RXNEIE`], node[`TXE` ∧ `TXEIE`], node[`TC` ∧ `TCIE`],
    )
    #arrow
    #node[OR: общий запрос USART1 (также возможны другие источники, например ошибки)]
    #arrow
    #node[NVIC: разрешение, pending, приоритет]
    #arrow
    #node[Ядро Cortex-M7: вход в исключение, сохранение контекста]
    #arrow
    #node[`USART1_IRQHandler()` → `HAL_UART_IRQHandler()`]
  ],
  caption: [Упрощённая схема формирования и обработки прерывания USART1],
) <fig-irq>

Запрос формируется аппаратной логикой, а не программным опросом флагов. NVIC управляет запросами; адреса обработчиков находятся в таблице векторов, базовый адрес которой задаётся регистром VTOR блока SCB. Для USART1 линия NVIC имеет номер 37, соответствующий индексу 53 в таблице векторов. EXTI для обычных событий USART не используется: USART имеет собственную линию IRQ. EXTI, напротив, позволяет формировать запросы, например, при изменении уровня GPIO; источник линии выбирается через SYSCFG.

= Часть 1. Архитектура программы для STM32

Программа разделена на прикладной уровень и драйверы. Основной цикл обновляет кнопку, конечный автомат светофора и обработчик команд. Детали работы с периферией скрыты в драйверах. Связи модулей показаны на @fig-architecture.

#figure(
  block(width: 100%)[
    #node[`main.c` — основной цикл]
    #arrow
    #grid(
      columns: (1fr, 1fr, 1fr),
      gutter: 6pt,
      node[`button.c`], node[`traffic_light.c`], node[`command_parser.c`],
    )
    #align(center)[↓ #h(18mm) ↓ #h(18mm) ↓]
    #grid(
      columns: (1fr, 1fr, 1fr),
      gutter: 6pt,
      node[`gpio_driver.c`], node[`led.c`], node[`uart_driver.c`],
    )
    #align(center)[↓ #h(18mm) ↓ #h(18mm) ↓]
    #grid(
      columns: (1fr, 1fr, 1fr),
      gutter: 6pt,
      node[GPIO], node[`gpio_driver.c` → GPIO], node[`ring_buffer.c` / HAL USART],
    )
    #v(3pt)
    #align(center)[Парсер также обращается к интерфейсу `traffic_light.c`.]
  ],
  caption: [Связи программных компонентов],
) <fig-architecture>

== Конечный автомат светофора

Сохраняется последовательность фаз предыдущей работы: красный, постоянный зелёный, мигающий зелёный, жёлтый. Длительность обычной красной фазы по умолчанию составляет 12 с, зелёной — 3 с, мигающей — 2 с, жёлтой — 3 с. Во время мигания зелёный светодиод переключается с интервалом 300 мс. Время отсчитывается через `HAL_GetTick()`, блокирующие задержки в конечном автомате отсутствуют.

В режиме 1 событие кнопки во время красного сокращает оставшееся время до 3 с, если остаток превышает это значение. Во время мигающего зелёного или жёлтого нажатие устанавливает флаг сокращения следующей красной фазы до четверти настроенного тайм-аута (3 с при обычных 12 с). На постоянном зелёном нажатие игнорируется. В режиме 2 события кнопки игнорируются; отложенное сокращение отменяется. Изменение тайм-аута применяется со следующей красной фазы. Уже начатая фаза не пересчитывается. Эти правила отражают реализованную адаптацию алгоритма предыдущей работы.

#figure(
  block(width: 100%)[
    #node[RED: `time_to_shine_red`]
    #align(center)[↓ по истечении времени]
    #node[GREEN: 3000 мс]
    #arrow
    #node[BLINK_GREEN: 2000 мс, переключение каждые 300 мс]
    #arrow
    #node[YELLOW: 3000 мс]
    #align(center)[↓ переход к RED; применяется новый тайм-аут / флаг сокращения]
    #node[RED — начало нового цикла]
  ],
  caption: [Блок-схема конечного автомата],
) <fig-fsm>

На @fig-fsm показаны переходы по времени; обработка кнопки модифицирует длительность красного, но не изменяет порядок фаз. Изменяемые параметры и состояние доступны через функции `traffic_light_set_mode()`, `traffic_light_set_timeout()`, `traffic_light_get_mode()`, `traffic_light_get_timeout()` и `traffic_light_get_state()`.

== Универсальный кольцевой буфер

Для режима прерываний созданы независимые очереди RX и TX с полезной ёмкостью 128 и 256 байтов соответственно. Размеры заданы при компиляции. Кольцевой буфер не зависит от HAL и конкретной прикладной задачи. Он хранит указатель на массив, размер массива и два индекса: `head` — следующая позиция записи, `tail` — следующая позиция чтения.

При совпадении индексов очередь пуста. При `(head + 1) % size == tail` очередь полна. Для различения этих двух состояний одна позиция массива остаётся зарезервированной; физические массивы имеют размеры 129 и 257 байтов. При заполнении `rb_push()` возвращает `false`, не перезаписывая непрочитанные данные. Функция `rb_peek()` позволяет получить первый элемент без его извлечения, что применяется при запуске передачи. Программные очереди проверялись отдельно на Linux до внедрения в прошивку.

== Режим опроса

При чтении используется `HAL_UART_Receive(&huart1, byte, 1, 0)`: если данные готовы, возвращается `HAL_OK`, иначе — `HAL_TIMEOUT` при отсутствии байта. Нулевой тайм-аут исключает длительное ожидание ввода. Передача в этом режиме выполняется функцией `HAL_UART_Transmit()` с ограниченным тайм-аутом 10 мс. В режиме опроса прерывания USART1 запрещены на уровне NVIC, а асинхронный приём не запущен.

При длительном выполнении прикладной логики могут теряться входящие данные: если RDR не прочитан до поступления очередного кадра, в стандартной конфигурации USART возникает ошибка переполнения ORE. Это ограничение режима опроса, не устраняемое использованием нулевого тайм-аута.

== Режим прерываний

`HAL_UART_Receive_IT()` сохраняет адрес буфера приёма и число ожидаемых байтов, разрешает соответствующие источники прерываний USART и возвращается без ожидания кадра. При поступлении байта USART формирует запрос IRQ; `USART1_IRQHandler()` передаёт управление HAL. HAL читает RDR, записывает байт в `rx_byte`, после чего вызывает `HAL_UART_RxCpltCallback()`. Собственный callback помещает байт в RX-очередь и повторно запускает приём. В основной программе `uart_read_byte()` читает только программную очередь и не обращается к блокирующей HAL-функции приёма в режиме I.

При передаче `uart_write_byte()` помещает байт в TX-очередь и вызывает `uart_tx_kick()`. Если передача свободна, запускается `HAL_UART_Transmit_IT()` для первого байта. Переменная `tx_byte` имеет статическое время жизни, поскольку HAL использует её адрес после возврата из функции. При завершении передачи `HAL_UART_TxCpltCallback()` снимает признак занятости и запускает передачу следующего байта. При полной очереди функция записи возвращает `HAL_BUSY`.

#figure(
  block(width: 100%)[
    #grid(
      columns: (1fr, 1fr),
      gutter: 12pt,
      [#node[RX: USART / RDR] #arrow #node[HAL IRQ → RX callback] #arrow #node[RX queue: `rb_push()`] #arrow #node[`main`: `rb_pop()`]],
      [#node[`main`: `rb_push()`] #arrow #node[TX queue] #arrow #node[`uart_tx_kick()` / TX callback] #arrow #node[HAL IRQ → TDR / USART]],
    )
  ],
  caption: [Потоки данных в режиме прерываний],
) <fig-buffers>

На @fig-buffers показано разделение на контексты основного цикла и прерывания. Общие структуры защищены короткими критическими секциями: значение PRIMASK сохраняется, маскируемые прерывания запрещаются, затем исходное значение восстанавливается. PRIMASK не изменяет приоритет USART в NVIC; он временно запрещает вход ядра в обработчики исключений с конфигурируемым приоритетом. Это защищает индексы очередей и согласованное изменение состояния передатчика. Критические секции не должны содержать длительных ожиданий.

== Переключение режима и команды

При включении прерываний драйвер очищает ожидающий запрос NVIC, запускает `HAL_UART_Receive_IT()` и разрешает IRQ USART1. При выключении сначала ожидается завершение передачи накопленных данных: если TX занят, возвращается `HAL_BUSY`. Затем асинхронный приём отменяется, линия NVIC запрещается, и драйвер переходит в polling. Уже накопленные данные RX могут быть прочитаны из очереди после переключения. Новые данные во время смены режима могут быть потеряны, поэтому команды передаются последовательно, после ответа на предыдущую.

Парсер накапливает символы в строке ёмкостью 64 байта, возвращая эхо. CR и LF завершают команду, а пара CRLF обрабатывается как один разделитель. Backspace поддерживается для редактирования строки. Ответ передаётся из отдельного буфера ёмкостью 128 байтов; при `HAL_BUSY` отправка откладывается. Команды изменения режима UART выполняются после передачи предшествующего вывода, без блокирования конечного автомата. Некорректный тайм-аут отклоняется, слишком длинная или неизвестная команда сопровождается диагностическим сообщением.

= Сборка и проверка первой части

Собственные модули добавлены в `target_sources()` проекта CMake: `uart_driver.c`, `ring_buffer.c`, `traffic_light.c`, `command_parser.c`, `gpio_driver.c`, `led.c`, `button.c`. Для clangd использовалась база `compile_commands.json`, формируемая CMake. Сборка, загрузка прошивки и открытие последовательного порта выполнялись следующими командами (путь к ELF соответствует имени проекта при первоначальной настройке):

```bash
cmake --preset Debug
cmake --build --preset Debug
openocd -f board/stm32f7discovery.cfg \
  -c "program build/Debug/uart_lab2.elf verify reset exit"
picocom -b 57600 /dev/ttyACM0
```

Сначала отдельно проверены эхо в polling, кольцевой буфер, приём и передача через прерывания, затем динамическое переключение режимов и совместная работа светофора с UART. Ниже приведён фактический вывод терминала, полученный после подключения парсера команд.

```text
Type [C-a] [C-h] to see available commands
Terminal ready
w]��a���Interrupt UART ready!
?
red, mode 1, timeout 12, P
set mode 2
OK
set timeout 5
OK
set interrupts on
Unknown command
set interrupts on
OK
?
yellow, mode 2, timeout 5, I
set timeout -10
Invalid argument
hello
Unknown command
set interrupts off
OK
?
green, mode 2, timeout 5, P

Terminating...
Thanks for using picocom
```

Из вывода следует, что изменение режима кнопки и тайм-аута выполняется, состояние UART меняется с P на I и обратно; отрицательный тайм-аут отклоняется, неизвестная команда распознаётся. На одном из первых вызовов команды переключения получено `Unknown command`; повторный вызов успешен. В начале сеанса также присутствуют искажённые символы и оставшееся от промежуточного теста сообщение. Причина этих отклонений экспериментально не установлена. Поэтому приведённый лог не является доказательством безошибочного обмена при произвольной нагрузке.

Различия polling и interrupt при ручном вводе обычно незаметны пользователю: прикладные команды одинаковы. Для инструментальной проверки можно установить аппаратную точку останова GDB на `USART1_IRQHandler` или `HAL_UART_RxCpltCallback`, убедившись, что при обмене в режиме P обработчик не вызывается, а в режиме I вызывается. Такой тест предложен как дополнительный способ проверки; протокол его фактического выполнения не приводится.

= Часть 2. Программный симулятор стенда

В соответствии со способом 2 разработано отдельное консольное приложение на C для Linux. Симуляция регистров, аппаратных IRQ и электрических сигналов USART не производится. Прикладная логика и формат команд сохранены, а аппаратно-зависимые функции заменены реализациями для POSIX. Это позволяет проверять взаимодействие клиента со стендом без платы STM32.

== Архитектура и виртуальный канал

Утилита `socat` создаёт пару псевдотерминалов PTY и перенаправляет данные между ними. Один конец открывает симулятор, другой — picocom. На @fig-simulator представлена схема взаимодействия.

#figure(
  block(width: 100%)[
    #node[Клиент: `picocom -b 57600 /tmp/uart_client`]
    #align(center)[↕]
    #node[`/tmp/uart_client` — PTY]
    #align(center)[↕]
    #node[`socat` — двунаправленная пересылка данных]
    #align(center)[↕]
    #node[`/tmp/uart_sim` — PTY]
    #align(center)[↕]
    #node[Симулятор: POSIX UART-драйвер → парсер → конечный автомат]
    #align(center)[Кнопка: stdin (`b` + Enter); светодиоды: stdout]
  ],
  caption: [Связь клиента с симулятором через PTY],
) <fig-simulator>

Конечный автомат `traffic_light.c` перенесён из прошивки без изменений. Парсер адаптирован минимально: вместо `main.h` подключён `stdlib.h`, вместо `Error_Handler()` используется `abort()`. В интерфейсе UART сохранены имена статусов и режимов для совместимости, но типы объявлены локально, библиотека HAL не используется. Команды P/I изменяют логический режим, не переключая механизм ввода-вывода Linux. Это соответствует требованиям выбранного способа.

== Реализация платформенного слоя

Виртуальный порт открывается функцией `open()` с флагами `O_RDWR`, `O_NOCTTY` и `O_NONBLOCK`. Настройки `termios` переводят устройство в raw-режим, отключают программную обработку символов и задают скорость B57600. Функции `read()` и `write()` возвращаются без ожидания; `EAGAIN` и `EWOULDBLOCK` преобразуются в статусы отсутствия данных или занятости. Кольцевые буферы STM32 не нужны: используется буферизация ввода-вывода операционной системы.

Время получается через `clock_gettime(CLOCK_MONOTONIC)`, результат переводится в миллисекунды. Функция `poll()` с нулевым тайм-аутом проверяет стандартный ввод; строчная буква `b`, введённая с Enter в терминале симулятора, имитирует событие кнопки. Модуль LED хранит три логических состояния и выводит сообщения вида `[LED] RED ON` при изменении. В основном цикле используется `nanosleep()` с интервалом 1 мс для ограничения загрузки процессора; RTOS и дополнительные потоки не используются.

== Сборка и запуск

Для симулятора создан отдельный CMake-проект с системным GCC и собственной базой `compile_commands.json`. Это необходимо, чтобы clangd не применял настройки ARM-компилятора к Linux-заголовкам `termios.h`, `poll.h`, `unistd.h`.

В первом терминале:

```bash
socat -d -d \
  PTY,raw,echo=0,link=/tmp/uart_sim \
  PTY,raw,echo=0,link=/tmp/uart_client
```

Проверка наличия портов:

```bash
ls -l /tmp/uart_sim /tmp/uart_client
```

Во втором терминале, в каталоге `simulator`:

```bash
cmake -S . -B build -DCMAKE_C_COMPILER=/usr/bin/gcc
cmake --build build
ln -sf build/compile_commands.json compile_commands.json
./build/simulator /tmp/uart_sim
```

В третьем терминале:

```bash
picocom -b 57600 /tmp/uart_client
```

Виртуальные порты созданы и проверены. По итогам ручного тестирования работа симулятора подтверждена: конечный автомат выполняется, команды обрабатываются через виртуальный канал, кнопка имитируется с помощью `b` и Enter. При режиме 1 нажатие сокращает красную фазу согласно алгоритму; при режиме 2 реакция отключается. Полная стенограмма сеанса симулятора не сохранена в материалах отчёта, поэтому здесь приводится описание проверки, а не реконструированный терминальный лог.

= Сопоставление с требованиями и ограничения

В @tab-result приведено сопоставление реализации с заданием. Проверки представлены на уровне реализованной функциональности и проведённых ручных испытаний; численные замеры задержек и тесты под непрерывной нагрузкой не выполнялись в рамках зафиксированных результатов.

#figure(
  table(
    columns: (1.4fr, 1.6fr),
    table.header([*Требование*], [*Результат реализации*]),
    [Polling на HAL], [`HAL_UART_Receive()` с тайм-аутом 0; передача через HAL.],
    [Interrupt на HAL], [Асинхронный RX/TX, callbacks, очередь каждого направления.],
    [Размер очередей при компиляции], [RX 128 и TX 256 байтов полезной ёмкости.],
    [Запрет USART IRQ в polling], [Отключение NVIC и отмена асинхронного приёма.],
    [Эхо и команды варианта], [Реализованы; фактический лог приведён в разделе 4.],
    [Симуляция прикладной логики], [Переиспользован конечный автомат и парсер.],
    [Виртуальный последовательный канал], [`socat`, два PTY, `picocom`.],
    [Режимы в симуляторе], [Условные P/I; аппаратные режимы не эмулируются.],
  ),
  caption: [Выполнение требований лабораторной работы],
) <tab-result>

В режиме опроса возможны потери данных при непрерывной передаче, а в interrupt-режиме конечная ёмкость очередей также ограничивает допустимую нагрузку. В PTY физическое время передачи кадров 57600 8N1 не воспроизводится. Прикладная программа в обеих реализациях не зависит от деталей аппаратного приёмопередатчика, что обеспечивает переносимость.

= Выводы

В ходе работы изучены организация последовательного обмена UART и механизмы аппаратных прерываний STM32. Реализованы два режима драйвера USART1 на базе HAL: опрос с неблокирующим приёмом и асинхронный приём/передача с программными очередями. Изучена роль RXNE, TXE и TC, контроллера NVIC и регистра PRIMASK. Разработан интерфейс управления светофором посредством текстовых команд, включая изменение параметров и переключение режима UART.

Во второй части разработан Linux-симулятор с применением POSIX API и виртуальных последовательных портов. Повторное использование конечного автомата и парсера продемонстрировало возможность отделения прикладной логики от аппаратно-зависимых драйверов. Проведённые функциональные проверки подтвердили работоспособность обеих реализаций при ручном управлении; отдельные аномалии начального обмена и ограничения при высокой нагрузке отмечены в отчёте.

= Использованные материалы

#enum(
  [Методические указания к лабораторной работе № 2 «Последовательный интерфейс UART», вариант 1, с. 78–80.],
  [STMicroelectronics. RM0385: STM32F75xxx and STM32F74xxx advanced Arm-based 32-bit MCUs. Разделы USART, GPIO, SYSCFG, EXTI.],
  [STMicroelectronics. PM0253: STM32F7 Series and STM32H7 Series Cortex-M7 processor programming manual. Разделы NVIC и exception model.],
  [Документация и исходные тексты STM32CubeF7 HAL: драйвер UART; CMSIS-Core.],
  [Linux man-pages: `open(2)`, `read(2)`, `write(2)`, `termios(3)`, `poll(2)`, `clock_gettime(2)`; справка `socat(1)` и `picocom(1)`.],
)

#pagebreak()
= Приложение А. Исходные коды первой части

Приведены значимые фрагменты собственной разработки по рабочему варианту, обсуждённому и проверенному при выполнении лабораторной. Сгенерированные CubeMX файлы, стандартные библиотеки и ранее разработанные GPIO/LED/button-модули не дублируются. Полное дерево репозитория в материалах отчёта отсутствует; листинги отражают использованные интерфейсы и алгоритмы, а не побайтовую копию окончательных файлов.

== Кольцевой буфер

#listing(
  "Интерфейс ring_buffer.h",
  ```
  #ifndef RING_BUFFER_H
  #define RING_BUFFER_H
  #include <stdbool.h>
  #include <stddef.h>
  #include <stdint.h>

  typedef struct {
    uint8_t *data;
    size_t size, head, tail;
  } ring_buffer_t;

  void rb_init(ring_buffer_t *rb, uint8_t *data, size_t size);
  bool rb_empty(const ring_buffer_t *rb);
  bool rb_full(const ring_buffer_t *rb);
  bool rb_push(ring_buffer_t *rb, uint8_t byte);
  bool rb_pop(ring_buffer_t *rb, uint8_t *byte);
  bool rb_peek(const ring_buffer_t *rb, uint8_t *byte);
  #endif
  ```.text,
)

#listing(
  "Основные операции ring_buffer.c",
  ```
  void rb_init(ring_buffer_t *rb, uint8_t *data, size_t size) {
    rb->data = data;
    rb->size = size;
    rb->head = rb->tail = 0;
  }

  bool rb_empty(const ring_buffer_t *rb) {
    return rb->head == rb->tail;
  }

  bool rb_full(const ring_buffer_t *rb) {
    return (rb->head + 1) % rb->size == rb->tail;
  }

  bool rb_push(ring_buffer_t *rb, uint8_t byte) {
    if (rb_full(rb)) return false;
    rb->data[rb->head] = byte;
    rb->head = (rb->head + 1) % rb->size;
    return true;
  }

  bool rb_pop(ring_buffer_t *rb, uint8_t *byte) {
    if (rb_empty(rb)) return false;
    *byte = rb->data[rb->tail];
    rb->tail = (rb->tail + 1) % rb->size;
    return true;
  }

  bool rb_peek(const ring_buffer_t *rb, uint8_t *byte) {
    if (rb_empty(rb)) return false;
    *byte = rb->data[rb->tail];
    return true;
  }
  ```.text,
)

== UART-драйвер

#listing(
  "Интерфейс uart_driver.h",
  ```
  #ifndef UART_DRIVER_H
  #define UART_DRIVER_H
  #include "stm32f7xx_hal.h"

  typedef enum {
    UART_MODE_POLLING,
    UART_MODE_INTERRUPT
  } uart_mode_t;

  void uart_init(void);
  HAL_StatusTypeDef uart_read_byte(uint8_t *byte);
  HAL_StatusTypeDef uart_write_byte(uint8_t byte);
  HAL_StatusTypeDef uart_set_mode(uart_mode_t mode);
  uart_mode_t uart_get_mode(void);
  #endif
  ```.text,
)

#listing(
  "Состояние драйвера, критические секции и запуск TX",
  ```
  #include "uart_driver.h"
  #include "ring_buffer.h"
  #include <stdbool.h>

  extern UART_HandleTypeDef huart1;
  #define RX_CAPACITY 128u
  #define TX_CAPACITY 256u
  static uint8_t rx_storage[RX_CAPACITY + 1u];
  static uint8_t tx_storage[TX_CAPACITY + 1u];
  static ring_buffer_t rx_buffer, tx_buffer;
  static uint8_t rx_byte, tx_byte;
  static bool tx_busy;
  static uart_mode_t current_mode = UART_MODE_POLLING;
  static volatile uint32_t rx_overflows, rx_errors, tx_start_errors;

  static uint32_t irq_lock(void) {
    uint32_t primask = __get_PRIMASK();
    __disable_irq();
    return primask;
  }

  static void irq_unlock(uint32_t primask) {
    __set_PRIMASK(primask);
  }

  static void uart_tx_kick(void) {
    if (tx_busy || !rb_peek(&tx_buffer, &tx_byte)) return;
    if (HAL_UART_Transmit_IT(&huart1, &tx_byte, 1) == HAL_OK) {
      rb_pop(&tx_buffer, &tx_byte);
      tx_busy = true;
    } else {
      tx_start_errors++;
    }
  }

  void uart_init(void) {
    HAL_NVIC_DisableIRQ(USART1_IRQn);
    HAL_NVIC_ClearPendingIRQ(USART1_IRQn);
    rb_init(&rx_buffer, rx_storage, sizeof(rx_storage));
    rb_init(&tx_buffer, tx_storage, sizeof(tx_storage));
    tx_busy = false;
    current_mode = UART_MODE_POLLING;
  }
  ```.text,
)

#listing(
  "Чтение, запись и переключение режима",
  ```
  HAL_StatusTypeDef uart_read_byte(uint8_t *byte) {
    uint32_t primask = irq_lock();
    bool success = rb_pop(&rx_buffer, byte);
    irq_unlock(primask);
    if (success) return HAL_OK;
    if (current_mode == UART_MODE_POLLING)
      return HAL_UART_Receive(&huart1, byte, 1, 0);
    return HAL_TIMEOUT;
  }

  HAL_StatusTypeDef uart_write_byte(uint8_t byte) {
    if (current_mode == UART_MODE_POLLING)
      return HAL_UART_Transmit(&huart1, &byte, 1, 10);
    uint32_t primask = irq_lock();
    bool success = rb_push(&tx_buffer, byte);
    uart_tx_kick();
    irq_unlock(primask);
    return success ? HAL_OK : HAL_BUSY;
  }

  uart_mode_t uart_get_mode(void) { return current_mode; }

  HAL_StatusTypeDef uart_set_mode(uart_mode_t mode) {
    if (mode != UART_MODE_POLLING && mode != UART_MODE_INTERRUPT)
      return HAL_ERROR;
    uint32_t primask = irq_lock();
    HAL_StatusTypeDef status = HAL_OK;
    if (mode == current_mode) {
      irq_unlock(primask);
      return HAL_OK;
    }
    if (mode == UART_MODE_POLLING) {
      if (tx_busy || !rb_empty(&tx_buffer)) {
        uart_tx_kick();
        irq_unlock(primask);
        return HAL_BUSY;
      }
      status = HAL_UART_AbortReceive(&huart1);
      if (status == HAL_OK) {
        HAL_NVIC_DisableIRQ(USART1_IRQn);
        HAL_NVIC_ClearPendingIRQ(USART1_IRQn);
        current_mode = mode;
      }
    } else {
      HAL_NVIC_ClearPendingIRQ(USART1_IRQn);
      status = HAL_UART_Receive_IT(&huart1, &rx_byte, 1);
      if (status == HAL_OK) {
        current_mode = mode;
        HAL_NVIC_EnableIRQ(USART1_IRQn);
      }
    }
    irq_unlock(primask);
    return status;
  }
  ```.text,
)

#listing(
  "Callbacks завершения приёма, передачи и ошибки",
  ```
  void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {
    if (huart != &huart1) return;
    if (!rb_push(&rx_buffer, rx_byte)) rx_overflows++;
    if (huart->ErrorCode == HAL_UART_ERROR_NONE) {
      if (HAL_UART_Receive_IT(&huart1, &rx_byte, 1) != HAL_OK)
        rx_errors++;
    }
  }

  void HAL_UART_TxCpltCallback(UART_HandleTypeDef *huart) {
    if (huart != &huart1) return;
    tx_busy = false;
    uart_tx_kick();
  }

  void HAL_UART_ErrorCallback(UART_HandleTypeDef *huart) {
    if (huart != &huart1) return;
    rx_errors++;
    if (huart->RxState == HAL_UART_STATE_READY) {
      if (HAL_UART_Receive_IT(&huart1, &rx_byte, 1) != HAL_OK)
        rx_errors++;
    }
  }
  ```.text,
)

== Светофор

#listing(
  "Изменяемые параметры и конечный автомат traffic_light.c",
  ```
  #include "traffic_light.h"
  #include "led.h"
  static uint32_t init_time, last_blink_green, time_to_shine_red;
  static traffic_state_t current_state;
  static bool reduce_red_time = false;
  static uint32_t red_timeout = 12000u;
  static bool button_enabled = true;

  void traffic_light_init(uint32_t now) {
    init_time = now;
    current_state = TRAFFIC_RED;
    time_to_shine_red = red_timeout;
    reduce_red_time = false;
    led_set(LED_GREEN, false);
    led_set(LED_YELLOW, false);
    led_set(LED_RED, true);
  }

  void traffic_light_update(uint32_t now, bool button_pressed_event) {
    button_pressed_event = button_pressed_event && button_enabled;
    if (button_pressed_event &&
        (current_state == TRAFFIC_BLINK_GREEN ||
         current_state == TRAFFIC_YELLOW))
      reduce_red_time = true;

    switch (current_state) {
    case TRAFFIC_RED:
      if (button_pressed_event && (now-init_time) < time_to_shine_red &&
          time_to_shine_red-(now-init_time) > 3000u)
        time_to_shine_red = (now-init_time)+3000u;
      if ((now-init_time) >= time_to_shine_red) {
        led_set(LED_RED, false);
        led_set(LED_GREEN, true);
        current_state = TRAFFIC_GREEN;
        init_time = now;
      }
      break;
    case TRAFFIC_GREEN:
      if ((now-init_time) >= 3000u) {
        current_state = TRAFFIC_BLINK_GREEN;
        init_time = last_blink_green = now;
      }
      break;
    case TRAFFIC_BLINK_GREEN:
      if ((now-init_time) < 2000u && (now-last_blink_green) >= 300u) {
        led_toggle(LED_GREEN);
        last_blink_green = now;
      }
      if ((now-init_time) >= 2000u) {
        led_set(LED_GREEN, false);
        led_set(LED_YELLOW, true);
        current_state = TRAFFIC_YELLOW;
        init_time = now;
      }
      break;
    case TRAFFIC_YELLOW:
      if ((now-init_time) >= 3000u) {
        led_set(LED_YELLOW, false);
        led_set(LED_RED, true);
        time_to_shine_red = reduce_red_time ? red_timeout/4u : red_timeout;
        reduce_red_time = false;
        current_state = TRAFFIC_RED;
        init_time = now;
      }
      break;
    default: break;
    }
  }

  void traffic_light_set_timeout(uint32_t seconds) {
    if (seconds > 0 && seconds <= UINT32_MAX / 1000u)
      red_timeout = seconds * 1000u;
  }
  void traffic_light_set_mode(bool enabled) {
    button_enabled = enabled;
    if (!enabled) reduce_red_time = false;
  }
  uint32_t traffic_light_get_timeout(void) { return red_timeout / 1000u; }
  bool traffic_light_get_mode(void) { return button_enabled; }
  traffic_state_t traffic_light_get_state(void) { return current_state; }
  ```.text,
)

== Парсер и основной цикл

#listing(
  "command_parser.c: состояние и вспомогательные функции",
  ```
  #include "command_parser.h"
  #include "traffic_light.h"
  #include "uart_driver.h"
  #include "main.h"
  #include <stdio.h>
  #include <string.h>
  #define CMD_SIZE 64
  #define OUT_SIZE 128
  static char cmd[CMD_SIZE];
  static size_t cmd_len;
  static bool overflow, ignore_lf;
  static char out[OUT_SIZE];
  static size_t out_len, out_pos;
  static bool switch_pending;
  static uart_mode_t requested_mode;

  static void reply(const char *text) {
    strcpy(out, text);
    out_len = strlen(out);
    out_pos = 0;
  }
  static const char *state_to_string(traffic_state_t state) {
    switch (state) {
    case TRAFFIC_RED: return "red";
    case TRAFFIC_YELLOW: return "yellow";
    case TRAFFIC_GREEN: return "green";
    case TRAFFIC_BLINK_GREEN: return "blinking green";
    default: return "unknown";
    }
  }
  static bool parse_timeout(const char *str, uint32_t *result) {
    uint32_t value = 0;
    const uint32_t limit = UINT32_MAX / 1000u;
    if (*str == '\0') return false;
    while (*str) {
      if (*str < '0' || *str > '9') return false;
      uint32_t digit = *str - '0';
      if (value > (limit - digit) / 10u) return false;
      value = value * 10u + digit;
      str++;
    }
    if (value == 0) return false;
    *result = value;
    return true;
  }
  ```.text,
)

#listing(
  "Распознавание команд",
  ```
  static void execute_command(void) {
    if (strcmp(cmd, "?") == 0) {
      snprintf(out, sizeof(out), "\r\n%s, mode %d, timeout %lu, %c\r\n",
        state_to_string(traffic_light_get_state()),
        traffic_light_get_mode() ? 1 : 2,
        (unsigned long)traffic_light_get_timeout(),
        uart_get_mode() == UART_MODE_INTERRUPT ? 'I' : 'P');
      out_len = strlen(out);
      out_pos = 0;
    } else if (strcmp(cmd, "set mode 1") == 0) {
      traffic_light_set_mode(true);
      reply("\r\nOK\r\n");
    } else if (strcmp(cmd, "set mode 2") == 0) {
      traffic_light_set_mode(false);
      reply("\r\nOK\r\n");
    } else if (strncmp(cmd, "set timeout ", 12) == 0) {
      uint32_t seconds;
      if (parse_timeout(cmd + 12, &seconds)) {
        traffic_light_set_timeout(seconds);
        reply("\r\nOK\r\n");
      } else {
        reply("\r\nInvalid argument\r\n");
      }
    } else if (strcmp(cmd, "set interrupts on") == 0) {
      requested_mode = UART_MODE_INTERRUPT;
      switch_pending = true;
      reply("\r\n");
    } else if (strcmp(cmd, "set interrupts off") == 0) {
      requested_mode = UART_MODE_POLLING;
      switch_pending = true;
      reply("\r\n");
    } else {
      reply("\r\nUnknown command\r\n");
    }
  }
  ```.text,
)

#listing(
  "Неблокирующее обновление парсера",
  ```
  void command_parser_update(void) {
    if (out_pos < out_len) {
      HAL_StatusTypeDef status = uart_write_byte(out[out_pos]);
      if (status == HAL_OK) out_pos++;
      else if (status != HAL_BUSY) Error_Handler();
      return;
    }
    if (switch_pending) {
      HAL_StatusTypeDef status = uart_set_mode(requested_mode);
      if (status == HAL_OK) {
        switch_pending = false;
        reply("OK\r\n");
      } else if (status != HAL_BUSY) {
        switch_pending = false;
        reply("Error\r\n");
      }
      return;
    }
    uint8_t byte;
    if (uart_read_byte(&byte) != HAL_OK) return;
    if (byte == '\n' && ignore_lf) {
      ignore_lf = false;
      return;
    }
    ignore_lf = (byte == '\r');
    if (byte == '\r' || byte == '\n') {
      cmd[cmd_len] = '\0';
      if (overflow) reply("\r\nCommand too long\r\n");
      else if (cmd_len > 0) execute_command();
      else reply("\r\n");
      cmd_len = 0;
      overflow = false;
      return;
    }
    if (byte == '\b' || byte == 127) {
      if (cmd_len > 0 && !overflow) {
        cmd_len--;
        reply("\b \b");
      }
      return;
    }
    out[0] = byte;
    out_len = 1;
    out_pos = 0;
    if (cmd_len < sizeof(cmd)-1 && !overflow) {
      cmd[cmd_len++] = byte;
    } else {
      overflow = true;
    }
  }
  ```.text,
)

#listing(
  "main.c: прикладная часть после инициализации периферии и GPIO",
  ```
  uart_init();
  traffic_light_init(HAL_GetTick());
  while (1) {
    uint32_t now = HAL_GetTick();
    bool pressed_event = button_update(now);
    traffic_light_update(now, pressed_event);
    command_parser_update();
  }
  ```.text,
)

#pagebreak()
= Приложение Б. Исходные коды симулятора

Приведены новые модули платформенного слоя; перенесённые `traffic_light.c` и `command_parser.c` повторно не приводятся.

== UART на POSIX

#listing(
  "uart_driver.h",
  ```
  #ifndef UART_DRIVER_H
  #define UART_DRIVER_H
  #include <stdint.h>

  typedef enum { HAL_OK, HAL_ERROR, HAL_BUSY, HAL_TIMEOUT }
    HAL_StatusTypeDef;
  typedef enum { UART_MODE_POLLING, UART_MODE_INTERRUPT } uart_mode_t;
  int uart_init(const char *path);
  HAL_StatusTypeDef uart_read_byte(uint8_t *byte);
  HAL_StatusTypeDef uart_write_byte(uint8_t byte);
  HAL_StatusTypeDef uart_set_mode(uart_mode_t mode);
  uart_mode_t uart_get_mode(void);
  #endif
  ```.text,
)

#listing(
  "uart_driver.c",
  ```
  #include "uart_driver.h"
  #include <errno.h>
  #include <fcntl.h>
  #include <termios.h>
  #include <unistd.h>
  static int fd = -1;
  static uart_mode_t current_mode = UART_MODE_POLLING;

  int uart_init(const char *path) {
    fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd < 0) return -1;
    struct termios tty;
    if (tcgetattr(fd, &tty) < 0) goto error;
    cfmakeraw(&tty);
    cfsetispeed(&tty, B57600);
    cfsetospeed(&tty, B57600);
    tty.c_cflag |= CLOCAL | CREAD;
    tty.c_cflag &= ~CRTSCTS;
    if (tcsetattr(fd, TCSANOW, &tty) < 0) goto error;
    return 0;
  error:
    close(fd);
    fd = -1;
    return -1;
  }
  HAL_StatusTypeDef uart_read_byte(uint8_t *byte) {
    ssize_t result = read(fd, byte, 1);
    if (result == 1) return HAL_OK;
    if (result == 0 || errno == EAGAIN || errno == EWOULDBLOCK ||
        errno == EINTR) return HAL_TIMEOUT;
    return HAL_ERROR;
  }
  HAL_StatusTypeDef uart_write_byte(uint8_t byte) {
    ssize_t result = write(fd, &byte, 1);
    if (result == 1) return HAL_OK;
    if (result == 0 || errno == EAGAIN || errno == EWOULDBLOCK ||
        errno == EINTR) return HAL_BUSY;
    return HAL_ERROR;
  }
  HAL_StatusTypeDef uart_set_mode(uart_mode_t mode) {
    current_mode = mode;
    return HAL_OK;
  }
  uart_mode_t uart_get_mode(void) { return current_mode; }
  ```.text,
)

== Светодиоды и кнопка

#listing(
  "led.h и led.c",
  ```
  // led.h
  #ifndef LED_H
  #define LED_H
  #include <stdbool.h>
  typedef enum { LED_RED, LED_YELLOW, LED_GREEN } led_t;
  void led_set(led_t led, bool enabled);
  void led_toggle(led_t led);
  #endif

  // led.c
  #include "led.h"
  #include <stdio.h>
  static bool states[3];
  static const char *names[] = {"RED", "YELLOW", "GREEN"};
  void led_set(led_t led, bool enabled) {
    if (states[led] == enabled) return;
    states[led] = enabled;
    printf("[LED] %s %s\n", names[led], enabled ? "ON" : "OFF");
  }
  void led_toggle(led_t led) { led_set(led, !states[led]); }
  ```.text,
)

#listing(
  "main.c: время, виртуальная кнопка и основной цикл",
  ```
  #include "traffic_light.h"
  #include "command_parser.h"
  #include "uart_driver.h"
  #include <poll.h>
  #include <stdint.h>
  #include <stdio.h>
  #include <time.h>
  #include <unistd.h>

  static uint32_t get_tick(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint32_t)((uint64_t)ts.tv_sec * 1000u +
                      ts.tv_nsec / 1000000u);
  }
  static bool button_update(void) {
    struct pollfd pfd = {.fd = STDIN_FILENO, .events = POLLIN};
    if (poll(&pfd, 1, 0) <= 0) return false;
    if (!(pfd.revents & POLLIN)) return false;
    char buf[64];
    ssize_t count = read(STDIN_FILENO, buf, sizeof(buf));
    for (ssize_t i = 0; i < count; i++) {
      if (buf[i] == 'b') return true;
    }
    return false;
  }
  int main(int argc, char **argv) {
    if (argc != 2) {
      fprintf(stderr, "Usage: %s <tty>\n", argv[0]);
      return 1;
    }
    if (uart_init(argv[1]) != 0) {
      perror("uart_init");
      return 1;
    }
    printf("Simulator ready: %s\n", argv[1]);
    printf("Press b + Enter to simulate button\n");
    traffic_light_init(get_tick());
    const struct timespec delay = {.tv_sec = 0, .tv_nsec = 1000000};
    while (1) {
      uint32_t now = get_tick();
      bool pressed_event = button_update();
      traffic_light_update(now, pressed_event);
      command_parser_update();
      nanosleep(&delay, NULL);
    }
  }
  ```.text,
)

== Конфигурация сборки

```cmake
cmake_minimum_required(VERSION 3.20)
project(simulator C)
set(CMAKE_C_STANDARD 11)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
add_executable(simulator
    main.c
    uart_driver.c
    command_parser.c
    traffic_light.c
    led.c
)
target_compile_definitions(simulator PRIVATE _DEFAULT_SOURCE)
target_compile_options(simulator PRIVATE -Wall -Wextra)
```
