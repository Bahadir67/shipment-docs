class ChecklistDefinition {
  final int index;
  final String category;
  final String label;

  const ChecklistDefinition(this.index, this.category, this.label);
}

class ChecklistDefinitions {
  static const List<ChecklistDefinition> items = [
    // --- MEKANIK & TANK (0-31) ---
    ChecklistDefinition(0, "MEKANIK & TANK", "Tank Ici Temizlik & Capak Kontrolu"),
    ChecklistDefinition(1, "MEKANIK & TANK", "Tank Dis Yuzey & Boya Kontrolu"),
    ChecklistDefinition(2, "MEKANIK & TANK", "Kapak Sizdirmazlik & Conta Durumu"),
    ChecklistDefinition(3, "MEKANIK & TANK", "Seviye Gostergesi Montaji & Gorunurluk"),
    ChecklistDefinition(4, "MEKANIK & TANK", "Dolum Kapagi & Hava Filtresi"),
    ChecklistDefinition(5, "MEKANIK & TANK", "Temizleme Kapagi (Manhole) Sikiligi"),
    ChecklistDefinition(6, "MEKANIK & TANK", "Ayaklar / Tekerlekler / Titresim Takozlari"),
    ChecklistDefinition(7, "MEKANIK & TANK", "Tasima Mapalari & Halkalari"),

    // --- MOTOR & POMPA (32-63) ---
    ChecklistDefinition(32, "MOTOR & POMPA", "Elektrik Motoru Montaji & Torklama"),
    ChecklistDefinition(33, "MOTOR & POMPA", "Hidrolik Pompa Montaji"),
    ChecklistDefinition(34, "MOTOR & POMPA", "Kaplin & Kaplin Lastigi Ayari"),
    ChecklistDefinition(35, "MOTOR & POMPA", "Kampana (Bell Housing) Baglantisi"),
    ChecklistDefinition(36, "MOTOR & POMPA", "Donus Yonu Etiketi (Motor Uzerinde)"),
    ChecklistDefinition(37, "MOTOR & POMPA", "Emis Hatti & Filtre Sikiligi"),
    ChecklistDefinition(38, "MOTOR & POMPA", "Donus Hatti & Filtre Montaji"),

    // --- HIDROLIK BLOK & TESISAT (64-95) ---
    ChecklistDefinition(64, "HIDROLIK BLOK & TESISAT", "Blok (Manifold) Temizligi & Montaji"),
    ChecklistDefinition(65, "HIDROLIK BLOK & TESISAT", "Valf (Ventil) Yonleri & Dogrulugu"),
    ChecklistDefinition(66, "HIDROLIK BLOK & TESISAT", "Bobin (Coil) Kontrolu (Dogru Voltaj)"),
    ChecklistDefinition(67, "HIDROLIK BLOK & TESISAT", "Rakor Sikilik & Sizdirmazlik Kontrolu"),
    ChecklistDefinition(68, "HIDROLIK BLOK & TESISAT", "Hortum & Boru Guzergahi (Surten Yer Yok)"),
    ChecklistDefinition(69, "HIDROLIK BLOK & TESISAT", "Manometre (Saat) Montaji & Calismasi"),
    ChecklistDefinition(70, "HIDROLIK BLOK & TESISAT", "Sistem Tapalari (Kortapalar) Eksiksiz"),
    ChecklistDefinition(71, "HIDROLIK BLOK & TESISAT", "Akumulator Kontrolu (Gaz Basinci)"),

    // --- ELEKTRIK SISTEMI (96-109) ---
    ChecklistDefinition(96, "ELEKTRIK SISTEMI", "Motor Klemens Baglantisi (Yildiz/Ucgen)"),
    ChecklistDefinition(97, "ELEKTRIK SISTEMI", "Motor & Govde Topraklamasi"),
    ChecklistDefinition(98, "ELEKTRIK SISTEMI", "Valf Soketleri & Contalari"),
    ChecklistDefinition(99, "ELEKTRIK SISTEMI", "Bobin LED Isik Kontrolu"),
    ChecklistDefinition(100, "ELEKTRIK SISTEMI", "Basinc Salteri / Transmiter Ayari"),
    ChecklistDefinition(101, "ELEKTRIK SISTEMI", "Seviye & Isi Sensoru Kablolari"),
    ChecklistDefinition(102, "ELEKTRIK SISTEMI", "Kablo Kodlama & Etiketleme"),
    ChecklistDefinition(103, "ELEKTRIK SISTEMI", "Spiral Hortum & Kablo Rekorlari"),
    ChecklistDefinition(104, "ELEKTRIK SISTEMI", "Pano Ici Duzen & Sigorta Kontrolu"),
    ChecklistDefinition(105, "ELEKTRIK SISTEMI", "Donus Yonu Testi (Motor Baglantisi)"),

    // --- SON TESTLER & SEVKIYAT (110-127) ---
    ChecklistDefinition(110, "SON TESTLER & SEVKIYAT", "Yag Dolumu Gerceklestirildi"),
    ChecklistDefinition(111, "SON TESTLER & SEVKIYAT", "Acil Stop & Emniyet Devresi Testi"),
    ChecklistDefinition(112, "SON TESTLER & SEVKIYAT", "Sistem Basinc Ayari Yapildi"),
    ChecklistDefinition(113, "SON TESTLER & SEVKIYAT", "Sizdirmazlik & Kacak Testi (Basincta)"),
    ChecklistDefinition(114, "SON TESTLER & SEVKIYAT", "Fonksiyon Testi (Tum Hareketler)"),
    ChecklistDefinition(115, "SON TESTLER & SEVKIYAT", "Urun Etiketi (Metal Plaka) Cakildi"),
    ChecklistDefinition(116, "SON TESTLER & SEVKIYAT", "Son Temizlik & Paketleme Onayi"),
  ];
}
