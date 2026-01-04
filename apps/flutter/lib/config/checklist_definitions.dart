class ChecklistDefinition {
  final int index;
  final String category;
  final String label;

  const ChecklistDefinition(this.index, this.category, this.label);
}

class ChecklistDefinitions {
  static const List<ChecklistDefinition> items = [
    // MEKANIK (0-31)
    ChecklistDefinition(0, "MEKANIK & TANK", "Tank Ici Temizlik & Capak Kontrolu"),
    ChecklistDefinition(1, "MEKANIK & TANK", "Tank Dis Yuzey & Boya Kontrolu"),
    ChecklistDefinition(2, "MEKANIK & TANK", "Kapak Sizdirmazlik & Conta"),
    ChecklistDefinition(3, "MEKANIK & TANK", "Seviye Gostergesi Montaji"),
    ChecklistDefinition(4, "MEKANIK & TANK", "Dolum Kapagi & Hava Filtresi"),
    ChecklistDefinition(5, "MEKANIK & TANK", "Temizleme Kapagi (Manhole)"),
    ChecklistDefinition(6, "MEKANIK & TANK", "Ayaklar / Tekerlekler / Titresim Takozlari"),
    ChecklistDefinition(7, "MEKANIK & TANK", "Tasima Mapalari / Halkalari"),

    // MOTOR & POMPA (32-63)
    ChecklistDefinition(32, "MOTOR & POMPA", "Elektrik Motoru Montaji"),
    ChecklistDefinition(33, "MOTOR & POMPA", "Hidrolik Pompa Montaji"),
    ChecklistDefinition(34, "MOTOR & POMPA", "Kaplin & Kaplin Lastigi Kontrolu"),
    ChecklistDefinition(35, "MOTOR & POMPA", "Kampana (Bell Housing) Baglantisi"),
    ChecklistDefinition(36, "MOTOR & POMPA", "Donus Yonu Etiketi"),
    ChecklistDefinition(37, "MOTOR & POMPA", "Emis Hatti & Filtresi"),
    ChecklistDefinition(38, "MOTOR & POMPA", "Donus Hatti & Filtresi"),

    // HIDROLIK BLOK (64-95)
    ChecklistDefinition(64, "HIDROLIK BLOK", "Blok (Manifold) Montaji"),
    ChecklistDefinition(65, "HIDROLIK BLOK", "Valf (Ventil) Montajlari"),
    ChecklistDefinition(66, "HIDROLIK BLOK", "Bobin (Coil) Kontrolu"),
    ChecklistDefinition(67, "HIDROLIK BLOK", "Rakor Sikilik Kontrolu"),
    ChecklistDefinition(68, "HIDROLIK BLOK", "Hortum & Boru Guzergahi"),
    ChecklistDefinition(69, "HIDROLIK BLOK", "Manometre (Saat) Montaji"),
    ChecklistDefinition(70, "HIDROLIK BLOK", "Sistem Tapalari (Kortapalar)"),
    ChecklistDefinition(71, "HIDROLIK BLOK", "Akumulator Kontrolu"),

    // ELEKTRIK & TEST (96-127)
    ChecklistDefinition(96, "ELEKTRIK & TEST", "Motor Klemens Baglantisi"),
    ChecklistDefinition(97, "ELEKTRIK & TEST", "Valf Soket Baglantilari & Isiklari"),
    ChecklistDefinition(98, "ELEKTRIK & TEST", "Basinc Salteri / Sensor Kablolari"),
    ChecklistDefinition(99, "ELEKTRIK & TEST", "Seviye / Isi Sensoru Kablolari"),
    ChecklistDefinition(100, "ELEKTRIK & TEST", "Fan / Sogutucu Baglantisi"),
    ChecklistDefinition(101, "ELEKTRIK & TEST", "Kablo Kanali / Spiral Duzeni"),
    ChecklistDefinition(102, "ELEKTRIK & TEST", "Yag Dolumu"),
    ChecklistDefinition(103, "ELEKTRIK & TEST", "Donus Yonu Testi"),
    ChecklistDefinition(104, "ELEKTRIK & TEST", "Basinc Ayari Yapildi"),
    ChecklistDefinition(105, "ELEKTRIK & TEST", "Sizdirmazlik / Kacak Testi"),
    ChecklistDefinition(106, "ELEKTRIK & TEST", "Fonksiyon Testi"),
    ChecklistDefinition(107, "ELEKTRIK & TEST", "Urun Etiketi (Plaka) Cakildi"),
  ];
}
