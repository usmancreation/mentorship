import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';
import '../../widgets/fade_in_slide.dart';
class MentorProfileScreen extends StatefulWidget {
  const MentorProfileScreen({super.key});

  @override
  State<MentorProfileScreen> createState() => _MentorProfileScreenState();
}
class _MentorProfileScreenState extends State<MentorProfileScreen> {
  // --- STATE VARIABLES ---
  List<String> _selectedSkills = []; // Jo user ne select ki hain (Source of Truth)
  bool _isLoadingData = true;
  bool _isSaving = false;
  bool _showOtherInput = false; // "Other" click krne par field dikhane k liye

  final TextEditingController _customSkillController = TextEditingController();

  // --- PRE-DEFINED POPULAR SKILLS ---
  final List<String> _popularSkills = [
    "Flutter Dev",
    "Graphic Design",
    "Web Development",
    "Digital Marketing",
    "SEO Expert",
    "Python",
  ];
  @override
  void initState() {
    super.initState();
    _fetchLatestSkillsFromDB();
  }

  // --- 1. FETCH FROM DB ---
  Future<void> _fetchLatestSkillsFromDB() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mId = prefs.getString('mentorId') ?? "";

    try {
      var response = await http.post(
        Uri.parse('https://techrisepk.com/mentor/mentorauth/get_mentor_skills.php'),
        body: {'mentor_id': mId}
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          String rawSkills = jsonResponse['skills'];
          
          setState(() {
            if (rawSkills.isNotEmpty) {
              // DB se ayi hui skills ko list bana kar selected ma daal do
              _selectedSkills = rawSkills.split(',').map((e) => e.trim()).toList();
            }
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoadingData = false);
    }
  }

  // --- 2. SAVE TO DB ---
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mId = prefs.getString('mentorId') ?? "";

    // List ko wapis String bana do
    String finalSkillsString = _selectedSkills.join(", ");

    try {
      var response = await http.post(
        Uri.parse('https://techrisepk.com/mentor/mentorauth/update_skills.php'),
        body: {
          'mentor_id': mId,
          'skills': finalSkillsString,
        }
      );

      if(response.statusCode == 200) {
        await prefs.setString('mentorSkills', finalSkillsString);
        
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Skills Updated Successfully!")));
        Navigator.pop(context, true); 
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network Error")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- TOGGLE SELECTION LOGIC ---
  void _toggleSkill(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  // --- ADD CUSTOM SKILL ---
  void _addCustomSkill() {
    if (_customSkillController.text.trim().isEmpty) return;
    
    String newSkill = _customSkillController.text.trim();
    if (!_selectedSkills.contains(newSkill)) {
      setState(() {
        _selectedSkills.add(newSkill);
        _customSkillController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Skills", style: TextStyle(color: AppColors.primaryYellow)),
        backgroundColor: AppColors.primaryBlack,
        iconTheme: const IconThemeData(color: AppColors.primaryYellow),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true), 
        ),
      ),
      body: _isLoadingData 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlack))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- SECTION 1: SELECTED SKILLS (Preview) ---
                  const Text("Your Active Skills", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text("These will be shown on your profile.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 15),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200)
                    ),
                    child: _selectedSkills.isEmpty
                      ? const Text("No skills selected yet.", style: TextStyle(color: Colors.grey))
                      : Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: _selectedSkills.map((skill) {
                            return Chip(
                              label: Text(skill),
                              backgroundColor: AppColors.primaryBlack,
                              labelStyle: const TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold),
                              deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white70),
                              onDeleted: () => _toggleSkill(skill), // Cross button to remove
                            );
                          }).toList(),
                        ),
                  ),

                  const SizedBox(height: 30),

                  // --- SECTION 2: QUICK SELECT (Chips) ---
                  const Text("Quick Add", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: [
                      // Popular Skills Chips
                      ..._popularSkills.map((skill) {
                        bool isSelected = _selectedSkills.contains(skill);
                        return GestureDetector(
                          onTap: () => _toggleSkill(skill),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryYellow : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryBlack : Colors.transparent,
                                width: 1.5
                              ),
                            ),
                            child: Text(
                              skill,
                              style: TextStyle(
                                color: isSelected ? AppColors.primaryBlack : Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),

                      // "Other" Chip
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showOtherInput = !_showOtherInput;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _showOtherInput ? AppColors.primaryBlack : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.grey.shade300)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 18, color: _showOtherInput ? Colors.white : Colors.black54),
                              const SizedBox(width: 5),
                              Text(
                                "Other",
                                style: TextStyle(
                                  color: _showOtherInput ? Colors.white : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // --- SECTION 3: CUSTOM INPUT (Visible only if Other clicked) ---
                  if (_showOtherInput) ...[
                    const SizedBox(height: 20),
                    FadeInSlide( // Optional: Agar animation widget nahi ha to remove kr dein
                      delay: 0.1, 
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customSkillController,
                              decoration: InputDecoration(
                                hintText: "Type custom skill...",
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade300)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: AppColors.primaryBlack)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FloatingActionButton.small(
                            onPressed: _addCustomSkill,
                            backgroundColor: AppColors.primaryBlack,
                            child: const Icon(Icons.check, color: AppColors.primaryYellow),
                          )
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // --- SAVE BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlack,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                      ),
                      child: _isSaving 
                       ? const CircularProgressIndicator(color: AppColors.primaryYellow)
                       : const Text("SAVE CHANGES", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}

// NOTE: Agar 'FadeInSlide' widget import nahi kiya hua to usay upar wali line se hata dein, ya import add kr dein.