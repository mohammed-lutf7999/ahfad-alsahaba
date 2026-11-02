import 'package:flutter/material.dart';

/// Represents a single project in the Creative Empire screen.
class EmpireProject {
  final String name;
  final String shortDesc;
  final String fullDesc;
  final IconData icon;

  const EmpireProject({
    required this.name,
    required this.shortDesc,
    required this.fullDesc,
    required this.icon,
  });
}

/// Represents a section/category of projects (e.g., "Islamic Apps").
class EmpireSection {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final List<EmpireProject> projects;

  const EmpireSection({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.projects,
  });
}
