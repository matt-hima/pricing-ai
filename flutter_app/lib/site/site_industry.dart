/// 業種別的預約需求（assets/editor/CHEATSHEET.md「Business types」，來源：予約システム比較「業種別の導入事例」）。
/// 聊天初始化時：依描述判斷業種 → 提示模型這個業種常見的需求 → 自動加上對應的預約欄位。

const industryIds = ['restaurant', 'salon', 'school', 'space', 'clinic', 'other'];

/// 提示模型的業種需求（英文；寫進系統提示詞）
const industryNeeds = {
  'restaurant': 'a restaurant or café: guests book a time slot and a table, so lunch and dinner hours matter; show the menu or course prices; mention prepayment or cancellation rules because no-shows hurt.',
  'salon': 'a hair or beauty salon: guests book a menu item and often choose a stylist; list the main menu items with prices; opening hours matter because many book after work or early in the morning.',
  'school': 'a school or lessons: guests ask for a trial lesson first; list the courses with monthly fees; lesson times and make-up lessons matter.',
  'space': 'a rental space or facility: guests book a block of hours; list the hourly or half-day price; the number of people and the purpose of use matter; say how the entry code or key is handled.',
  'clinic': 'a clinic: patients book a visit slot, either a first visit or a return visit; list the clinic hours and the main treatments; reminders and how to change or cancel matter.',
};

const industryLabels = {
  'restaurant': 'restaurant / café',
  'salon': 'salon / beauty',
  'school': 'school / lessons',
  'space': 'rental space / facility',
  'clinic': 'clinic',
  'other': 'other',
};

// 偵測用關鍵字（小寫比對）：日 / 英 / 中
const _keywords = {
  'clinic': ['clínica', 'clinica', 'consultório', 'consultorio', 'dentista', 'pediatria', 'クリニック', '病院', '医院', '歯科', '診療', '内科', '皮膚科', 'clinic', 'dentist', 'dental', 'doctor', 'medical', '診所', '醫院', '牙科', '看診', '門診'],
  'space': ['espaço', 'espacio', 'sala de reuniões', 'sala de reuniones', 'alquiler', 'aluguel', 'レンタルスペース', '貸し会議室', '会議室', '貸切', 'コワーキング', 'スタジオ貸', 'rental space', 'meeting room', 'co-working', 'coworking', 'venue', '場地', '租借', '共享空間', '會議室'],
  'school': ['escola', 'escuela', 'aulas', 'clases', 'academia', '教室', 'スクール', '習い事', 'レッスン', '塾', 'school', 'lesson', 'class', 'course', 'tutoring', '補習', '課程', '教室', '才藝', '學校'],
  'salon': ['salão', 'salón', 'cabeleireiro', 'peluquería', 'peluqueria', 'manicure', 'uñas', '美容室', '美容院', 'サロン', 'ヘア', 'ネイル', 'エステ', 'まつげ', 'マッサージ', 'salon', 'hair', 'nail', 'beauty', 'spa', 'barber', 'massage', '美髮', '美甲', '美容', '按摩', '理髮'],
  'restaurant': ['restaurante', 'cafetería', 'cafeteria', 'lanchonete', 'レストラン', '飲食', '居酒屋', 'カフェ', '焼肉', 'ラーメン', '寿司', 'restaurant', 'cafe', 'café', 'bistro', 'bar', 'diner', 'izakaya', '餐廳', '餐飲', '咖啡', '居酒屋', '料理'],
};

/// 由描述判斷業種（先比對較具體的，例如診所、租借空間，再比對一般的）；判斷不出來回傳 'other'
String detectIndustry(String text) {
  final t = text.toLowerCase();
  for (final id in const ['clinic', 'space', 'school', 'salon', 'restaurant']) {
    if (_keywords[id]!.any((k) => t.contains(k.toLowerCase()))) return id;
  }
  return 'other';
}

typedef _Loc = Map<String, String>; // 語言碼 → 文字

class _Field {
  final _Loc label;
  final String kind;
  final _Loc? options; // 逗號分隔
  final bool required;
  const _Field(this.label, this.kind, {this.options, this.required = false});
}

const _guests = _Field(
  {'en': 'Number of guests', 'ja': '人数', 'zh': '人數', 'pt': 'Número de pessoas', 'es': 'Número de personas'},
  'number',
  required: true,
);
const _seat = _Field(
  {'en': 'Seat preference', 'ja': 'ご希望のお席', 'zh': '座位偏好', 'pt': 'Preferência de lugar', 'es': 'Preferencia de asiento'},
  'select',
  options: {'en': 'No preference, Table, Counter, Private room', 'ja': 'こだわりなし, テーブル席, カウンター席, 個室', 'zh': '不指定, 桌位, 吧檯座位, 包廂', 'pt': 'Sem preferência, Mesa, Balcão, Sala privativa', 'es': 'Sin preferencia, Mesa, Barra, Sala privada'},
);
const _stylist = _Field(
  {'en': 'Preferred stylist', 'ja': 'ご希望のスタッフ', 'zh': '指定設計師', 'pt': 'Profissional preferido', 'es': 'Profesional preferido'},
  'text',
);
const _lesson = _Field(
  {'en': 'Lesson type', 'ja': 'ご希望のレッスン', 'zh': '課程類型', 'pt': 'Tipo de aula', 'es': 'Tipo de clase'},
  'select',
  options: {'en': 'Trial lesson, Regular lesson, Make-up lesson', 'ja': '体験レッスン, 通常レッスン, 振替レッスン', 'zh': '體驗課, 一般課程, 補課', 'pt': 'Aula experimental, Aula regular, Reposição', 'es': 'Clase de prueba, Clase regular, Recuperación'},
  required: true,
);
const _duration = _Field(
  {'en': 'Length of use', 'ja': 'ご利用時間', 'zh': '使用時間', 'pt': 'Duração', 'es': 'Duración'},
  'select',
  options: {'en': '1 hour, 2 hours, 3 hours, Half day, Full day', 'ja': '1時間, 2時間, 3時間, 半日, 終日', 'zh': '1 小時, 2 小時, 3 小時, 半天, 全天', 'pt': '1 hora, 2 horas, 3 horas, Meio dia, Dia inteiro', 'es': '1 hora, 2 horas, 3 horas, Media jornada, Día completo'},
  required: true,
);
const _purpose = _Field(
  {'en': 'Purpose of use', 'ja': 'ご利用目的', 'zh': '使用目的', 'pt': 'Finalidade', 'es': 'Finalidad'},
  'text',
);
const _visit = _Field(
  {'en': 'Visit type', 'ja': '受診区分', 'zh': '就診類型', 'pt': 'Tipo de consulta', 'es': 'Tipo de visita'},
  'select',
  options: {'en': 'First visit, Return visit', 'ja': '初診, 再診', 'zh': '初診, 複診', 'pt': 'Primeira consulta, Retorno', 'es': 'Primera visita, Revisión'},
  required: true,
);
const _reason = _Field(
  {'en': 'Reason for the visit', 'ja': 'ご相談内容', 'zh': '就診原因', 'pt': 'Motivo da consulta', 'es': 'Motivo de la consulta'},
  'textarea',
);

const _fieldsByIndustry = {
  'restaurant': [_guests, _seat],
  'salon': [_stylist],
  'school': [_lesson],
  'space': [_guests, _duration, _purpose],
  'clinic': [_visit, _reason],
};

/// 該業種要加到預約表單的問題，已經是編輯器動作（add_form_field）的格式
List<Map<String, Object?>> industryFieldActions(String industry, String lang) {
  final code = const {'en', 'ja', 'zh', 'pt', 'es'}.contains(lang) ? lang : 'en';
  return [
    for (final f in _fieldsByIndustry[industry] ?? const <_Field>[])
      {
        'action': 'add_form_field',
        'label': f.label[code] ?? f.label['en']!,
        'kind': f.kind,
        if (f.options != null) 'options': f.options![code] ?? f.options!['en']!,
        if (f.required) 'required': true,
      },
  ];
}

/// 業種別「當天流程」的預設步驟（流程圖用；來源：assets/editor/CHEATSHEET.md 的業種需求）。
/// 沒有對應業種時回傳 null，範本就用通用的步驟。
const _serviceSteps = <String, Map<String, List<String>>>{
  'restaurant': {
    'en': ['Arrive', 'Seated at your table', 'Order', 'Enjoy your meal', 'Payment'],
    'ja': ['ご来店', 'お席へご案内', 'ご注文', 'お食事', 'お会計'],
    'zh': ['到店', '帶位入座', '點餐', '享用餐點', '結帳'],
    'pt': ['Chegada', 'Acomodação na mesa', 'Pedido', 'Refeição', 'Pagamento'],
    'es': ['Llegada', 'Acomodo en la mesa', 'Pedido', 'Comida', 'Pago'],
  },
  'salon': {
    'en': ['Arrive', 'Consultation', 'Treatment', 'Finish and styling', 'Payment and next visit'],
    'ja': ['ご来店', 'カウンセリング', '施術', '仕上げ', 'お会計・次回のご予約'],
    'zh': ['到店', '諮詢溝通', '進行服務', '造型完成', '結帳與預約下次'],
    'pt': ['Chegada', 'Conversa inicial', 'Atendimento', 'Finalização', 'Pagamento e próxima visita'],
    'es': ['Llegada', 'Conversación inicial', 'Servicio', 'Acabado', 'Pago y próxima visita'],
  },
  'school': {
    'en': ['Arrive', 'Meet your teacher', 'Trial lesson', 'Talk about goals', 'Sign up'],
    'ja': ['ご来校', '先生とご挨拶', '体験レッスン', '目標のご相談', 'ご入会'],
    'zh': ['到校', '與老師見面', '體驗課程', '討論學習目標', '報名'],
    'pt': ['Chegada', 'Conhecer o professor', 'Aula experimental', 'Conversa sobre objetivos', 'Matrícula'],
    'es': ['Llegada', 'Conocer al profesor', 'Clase de prueba', 'Hablar de objetivos', 'Inscripción'],
  },
  'space': {
    'en': ['Receive the entry code', 'Enter and set up', 'Use the space', 'Tidy up', 'Check out'],
    'ja': ['入室コードを受け取る', '入室・準備', 'ご利用', '片付け', '退室'],
    'zh': ['收到入場代碼', '入場與準備', '使用空間', '整理場地', '退場'],
    'pt': ['Receber o código de entrada', 'Entrada e preparação', 'Uso do espaço', 'Arrumação', 'Saída'],
    'es': ['Recibir el código de entrada', 'Entrada y preparación', 'Uso del espacio', 'Recoger', 'Salida'],
  },
  'clinic': {
    'en': ['Arrive and check in', 'Fill in the form', 'Examination', 'Explanation', 'Payment and next visit'],
    'ja': ['ご来院・受付', '問診票の記入', '診察', 'ご説明', 'お会計・次回のご予約'],
    'zh': ['到院掛號', '填寫問診單', '看診', '說明與建議', '結帳與預約回診'],
    'pt': ['Chegada e recepção', 'Preencher a ficha', 'Consulta', 'Explicação', 'Pagamento e retorno'],
    'es': ['Llegada y recepción', 'Rellenar la ficha', 'Consulta', 'Explicación', 'Pago y próxima cita'],
  },
};

List<String>? industryServiceSteps(String industry, String lang) => _serviceSteps[industry]?[lang] ?? _serviceSteps[industry]?['en'];
