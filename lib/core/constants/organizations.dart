enum OrgCategory { academic, nonAcademic }

const Map<String, Map<OrgCategory, List<String>>> organizationData = {
  'isulan': {
    OrgCategory.academic: [
      'Computer Studies Students Organization (CSSO)',
      'Philippine Society of Information Technology Students (PSITS)',
      'Electronics Student Organization',
      'Society of Automotive Technology',
      'Junior IEEE',
      'Philippine Institute of Electronics and Communications Engineers (PhilICE)',
      'International Council of ECEP Engineers (ICPEP)',
      'Engineering Student Organization',
      'Nation Builders Association',
      'Student Body Organization - Isulan (SBO-Isulan)',
      'College of Criminal Justice Education Student Organization (CCJESO)',
      'College of Health Sciences Student Organization (CHSSO)',
      'Political Science Society',
      'Travel Club Organization',
      'Biological Society',
      'Junior Philippine Institute of Accountants (JPIA)',
      'Business Management Society',
    ],
    OrgCategory.nonAcademic: [
      'National Service Training Program (NSTP)',
      'Regeneration S.E.E.D.',
      'Book Club',
      'Psalm',
      'Peer Helpers Group',
      'Red Cross Youth Council (RCYC)',
      'KAMSU (Muslim Student Organization)',
      'SKSU-Muslim Student Organization',
    ],
  },
  'tacurong': {
    OrgCategory.academic: [
      'PSITS-Tacurong',
      'Junior PHP User Group',
      'IEEE-Tacurong',
      'SBO-Tacurong',
      'University Debate Council',
      'College of Education Student Organization',
    ],
    OrgCategory.nonAcademic: [
      'NSTP-Tacurong',
      'Red Cross Youth Tacurong (RCY Tacurong)',
      'Psalm Tacurong',
      'Hiraya Organization',
      'Sidlak Organization',
      'Peer Counselors',
    ],
  },
  'access': {
    OrgCategory.academic: [
      'Junior Educators of the Philippines (JEP)',
      'IT Society Organization (ITSO)',
      'SBO-ACCESS',
    ],
    OrgCategory.nonAcademic: [
      'NSTP-ACCESS',
      'Student Body Organization (SBO)',
      'Peer Helper Group (PHG)',
      'Campus First Aid Volunteer (CFAV)',
      'SKSU-ACCESS Red Cross Youth Council',
      'Student Volunteers',
    ],
  },
  'bagumbayan': {
    OrgCategory.academic: [
      'SBO-Bagumbayan',
      'Agribusiness Society',
      'TOF Organization',
      'Agri-Math Club',
    ],
    OrgCategory.nonAcademic: [
      'NSTP-Bagumbayan',
      'Youth Volunteers',
    ],
  },
  'palimbang': {
    OrgCategory.academic: [
      'SBO-Palimbang',
      'LEED Palimbang',
      'AgriBizz Society',
      'SPICS Palimbang',
    ],
    OrgCategory.nonAcademic: [
      'NSTP-Palimbang',
      'Teatro Palabunian',
      'Peer Counselors Palimbang',
    ],
  },
  'kalamansig': {
    OrgCategory.academic: [
      'SBO-Kalamansig',
      'Muslim Student Organization (MSO)',
    ],
    OrgCategory.nonAcademic: [
      'NSTP-Kalamansig',
      'Book Club',
      'Sports Club',
      'Peer Helpers Group',
    ],
  },
  'lutayan': {
    OrgCategory.academic: [
      'SBO-Lutayan',
      'SKSU Agri 4H Club',
      'Crop Science Student Society',
    ],
    OrgCategory.nonAcademic: [
      'NSTP-Lutayan',
      'Youth for Christ',
      'Peer Counselors Lutayan',
    ],
  },
};

class OrganizationData {
  OrganizationData._();

  static List<String> getOrganizations(String campusId, OrgCategory category) {
    return organizationData[campusId]?[category] ?? [];
  }

  static List<String> getAcademicOrganizations(String campusId) {
    return organizationData[campusId]?[OrgCategory.academic] ?? [];
  }

  static List<String> getNonAcademicOrganizations(String campusId) {
    return organizationData[campusId]?[OrgCategory.nonAcademic] ?? [];
  }
}
