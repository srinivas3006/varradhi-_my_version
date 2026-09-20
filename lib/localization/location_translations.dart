/// Comprehensive dictionary mapping English location names (states, districts, major cities)
/// to their authentic, native Telugu representations for UI presentation.
class LocationTranslations {
  LocationTranslations._();

  static const Map<String, String> _districtsAndStates = {
    // --- States ---
    'telangana': 'తెలంగాణ',
    'andhra pradesh': 'ఆంధ్రప్రదేశ్',
    'andhrapradesh': 'ఆంధ్రప్రదేశ్',
    'ap': 'ఆంధ్రప్రదేశ్',
    'ts': 'తెలంగాణ',
    'tg': 'తెలంగాణ',
    'india': 'భారత్',

    // --- Telangana Districts (All 33 Districts) ---
    'adilabad': 'ఆదిలాబాద్',
    'bhadradri kothagudem': 'భద్రాద్రి కొత్తగూడెం',
    'bhadradri': 'భద్రాద్రి కొత్తగూడెం',
    'kothagudem': 'కొత్తగూడెం',
    'hanumakonda': 'హనుమకొండ',
    'hanamkonda': 'హనుమకొండ',
    'hyderabad': 'హైదరాబాద్',
    'jagtial': 'జగిత్యాల',
    'jagitial': 'జగిత్యాల',
    'jangaon': 'జనగామ',
    'jayashankar bhupalpally': 'జయశంకర్ భూపాలపల్లి',
    'bhupalpally': 'భూపాలపల్లి',
    'jogulamba gadwal': 'జోగులాంబ గద్వాల',
    'gadwal': 'గద్వాల',
    'kamareddy': 'కామారెడ్డి',
    'karimnagar': 'కరీంనగర్',
    'khammam': 'ఖమ్మం',
    'kumuram bheem asifabad': 'కొమరం భీమ్ ఆసిఫాబాద్',
    'komaram bheem asifabad': 'కొమరం భీమ్ ఆసిఫాబాద్',
    'komaram bheem': 'కొమరం భీమ్',
    'asifabad': 'ఆసిఫాబాద్',
    'mahabubabad': 'మహబూబాబాద్',
    'mahabubnagar': 'మహబూబ్‌నగర్',
    'palamuru': 'పాలమూరు',
    'mancherial': 'మంచిర్యాల',
    'medak': 'మెదక్',
    'medchal malkajgiri': 'మేడ్చల్ మల్కాజ్‌గిరి',
    'medchal-malkajgiri': 'మేడ్చల్ మల్కాజ్‌గిరి',
    'medchal': 'మేడ్చల్',
    'malkajgiri': 'మల్కాజ్‌గిరి',
    'mulugu': 'ములుగు',
    'nagarkurnool': 'నాగర్‌కర్నూల్',
    'nalgonda': 'నల్గొండ',
    'narayanpet': 'నారాయణపేట',
    'nirmal': 'నిర్మల్',
    'nizamabad': 'నిజామాబాద్',
    'peddapalli': 'పెద్దపల్లి',
    'rajanna sircilla': 'రాజన్న సిరిసిల్ల',
    'sircilla': 'సిరిసిల్ల',
    'ranga reddy': 'రంగారెడ్డి',
    'rangareddy': 'రంగారెడ్డి',
    'sangareddy': 'సంగారెడ్డి',
    'siddipet': 'సిద్దిపేట',
    'suryapet': 'సూర్యాపేట',
    'vikarabad': 'వికారాబాద్',
    'wanaparthy': 'వనపర్తి',
    'warangal': 'వరంగల్',
    'yadadri bhuvanagiri': 'యాదాద్రి భువనగిరి',
    'yadadri': 'యాదాద్రి',
    'bhuvanagiri': 'భువనగిరి',

    // --- Andhra Pradesh Districts (All 26 Districts) ---
    'alluri sitharama raju': 'అల్లూరి సీతారామరాజు',
    'alluri sitarama raju': 'అల్లూరి సీతారామరాజు',
    'anakapalli': 'అనకాపల్లి',
    'ananthapuramu': 'అనంతపురం',
    'anantapur': 'అనంతపురం',
    'annamayya': 'అన్నమయ్య',
    'bapatla': 'బాపట్ల',
    'chittoor': 'చిత్తూరు',
    'dr. b.r. ambedkar konaseema': 'డా. బి.ఆర్. అంబేద్కర్ కోనసీమ',
    'dr b r ambedkar konaseema': 'కోనసీమ',
    'konaseema': 'కోనసీమ',
    'east godavari': 'తూర్పు గోదావరి',
    'eluru': 'ఏలూరు',
    'guntur': 'గుంటూరు',
    'kakinada': 'కాకినాడ',
    'krishna': 'కృష్ణా',
    'kurnool': 'కర్నూలు',
    'nandyal': 'నంద్యాల',
    'ntr': 'ఎన్టీఆర్',
    'palnadu': 'పల్నాడు',
    'parvathipuram manyam': 'పార్వతీపురం మన్యం',
    'manyam': 'మన్యం',
    'prakasam': 'ప్రకాశం',
    'sri potti sriramulu nellore': 'శ్రీ పొట్టి శ్రీరాములు నెల్లూరు',
    'sps nellore': 'నెల్లూరు',
    'nellore': 'నెల్లూరు',
    'sri sathya sai': 'శ్రీ సత్యసాయి',
    'sathya sai': 'శ్రీ సత్యసాయి',
    'srikakulam': 'శ్రీకాకుళం',
    'tirupati': 'తిరుపతి',
    'visakhapatnam': 'విశాఖపట్నం',
    'vizag': 'విశాఖపట్నం',
    'vizianagaram': 'విజయనగరం',
    'west godavari': 'పశ్చిమ గోదావరి',
    'ysr kadapa': 'వైఎస్సార్ కడప',
    'kadapa': 'కడప',

    // --- Prominent Cities & Mandals ---
    'secunderabad': 'సికింద్రాబాద్',
    'khairatabad': 'ఖైరతాబాద్',
    'amberpet': 'అంబర్‌పేట్',
    'jubilee hills': 'జూబ్లీహిల్స్',
    'banjara hills': 'బంజారాహిల్స్',
    'kukatapally': 'కూకట్‌పల్లి',
    'kukatpally': 'కూకట్‌పల్లి',
    'madhapur': 'మాదాపూర్',
    'gachibowli': 'గచ్చిబౌలి',
    'ameerpet': 'అమీర్‌పేట్',
    'dilsukhnagar': 'దిల్‌సుఖ్‌నగర్',
    'charminar': 'చార్మినార్',
    'hitec city': 'హైటెక్ సిటీ',
    'kondapur': 'కొండాపూర్',
    'miyapur': 'మియాపూర్',
    'uppal': 'ఉప్పల్',
    'lb nagar': 'ఎల్బీ నగర్',
    'begumpet': 'బేగంపేట్',
    'kesaram': 'కేసారం',
    'jajireddygudem': 'జాజిరెడ్డిగూడెం',
    'vijayawada': 'విజయవాడ',
    'amaravati': 'అమరావతి',
    'rajahmundry': 'రాజమండ్రి',
    'rajamahendravaram': 'రాజమహేంద్రవరం',
    'machilipatnam': 'మచిలీపట్నం',
    'ongole': 'ఒంగోలు',
    'bhimavaram': 'భీమవరం',
    'tenali': 'తెనాలి',
    'hindupur': 'హిందూపురం',
    'proddatur': 'ప్రొద్దుటూరు',
    'adoni': 'ఆదోని',
    'madanapalle': 'మదనపల్లె',
  };

  static final RegExp _teluguRegex = RegExp(r'[\u0C00-\u0C7F]');

  /// Converts any English location name into its Telugu equivalent.
  /// If the input is already in Telugu or empty, it is returned directly.
  static String toTelugu(String? name) {
    if (name == null) return '';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';

    // If already contains Telugu script, return as is
    if (_teluguRegex.hasMatch(trimmed)) {
      return trimmed;
    }

    final key = trimmed.toLowerCase();
    if (_districtsAndStates.containsKey(key)) {
      return _districtsAndStates[key]!;
    }

    // Check composite names like "Hyderabad, Telangana"
    if (trimmed.contains(',')) {
      final parts = trimmed.split(',').map((p) => toTelugu(p.trim())).toList();
      return parts.join(', ');
    }

    return trimmed;
  }

  /// Builds a localized display location string formatted for Telugu.
  static String formatDisplayLocation({
    required String state,
    required String district,
    String city = '',
    String subdistrict = '',
    String village = '',
  }) {
    final stateTe = toTelugu(state);
    final districtTe = toTelugu(district);
    final cityTe = toTelugu(city);
    final subdistrictTe = toTelugu(subdistrict);
    final villageTe = toTelugu(village);

    if (villageTe.isNotEmpty) {
      return subdistrictTe.isNotEmpty
          ? '$villageTe, $subdistrictTe'
          : (districtTe.isNotEmpty ? '$villageTe, $districtTe' : villageTe);
    } else if (subdistrictTe.isNotEmpty &&
        districtTe.isNotEmpty &&
        subdistrictTe != districtTe) {
      return '$subdistrictTe, $districtTe';
    } else if (cityTe.isNotEmpty && districtTe.isNotEmpty && cityTe != districtTe) {
      return '$cityTe, $districtTe';
    } else if (districtTe.isNotEmpty) {
      return stateTe.isNotEmpty ? '$districtTe, $stateTe' : districtTe;
    } else if (cityTe.isNotEmpty) {
      return stateTe.isNotEmpty ? '$cityTe, $stateTe' : cityTe;
    }
    return stateTe;
  }
}
