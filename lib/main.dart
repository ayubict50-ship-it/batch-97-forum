import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();

  runApp(const SamobayApp());
}

String globalSocietyName = '৯৭ ব্যাচ একতা ফোরাম';
String globalAdminId = 'admin';
String globalAdminPassword = '1234';

class InstallmentSlab {
  final String id;
  DateTime startDate;
  DateTime endDate;
  double amount;

  InstallmentSlab({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'amount': amount,
      };

  factory InstallmentSlab.fromJson(Map<String, dynamic> json) => InstallmentSlab(
        id: json['id'],
        startDate: DateTime.parse(json['startDate']),
        endDate: DateTime.parse(json['endDate']),
        amount: (json['amount'] as num).toDouble(),
      );
}

List<InstallmentSlab> globalInstallmentSlabs = [
  InstallmentSlab(
    id: '1',
    startDate: DateTime(2019, 1, 1),
    endDate: DateTime(2023, 12, 31),
    amount: 1000.0,
  ),
  InstallmentSlab(
    id: '2',
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2035, 12, 31),
    amount: 2000.0,
  ),
];

class SamobayApp extends StatelessWidget {
  const SamobayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: globalSocietyName,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class BusinessRecord {
  final String id;
  final String title;
  final double amount;
  final bool isIncome;
  final DateTime date;

  BusinessRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.isIncome,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'isIncome': isIncome,
        'date': date.toIso8601String(),
      };

  factory BusinessRecord.fromJson(Map<String, dynamic> json) => BusinessRecord(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        isIncome: json['isIncome'],
        date: DateTime.parse(json['date']),
      );
}

class TransactionHistory {
  final DateTime date;
  final double amount;
  final String paymentMethod;
  final String trxId;
  final bool isProfit;

  TransactionHistory({
    required this.date,
    required this.amount,
    required this.paymentMethod,
    this.trxId = '',
    this.isProfit = false,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'amount': amount,
        'paymentMethod': paymentMethod,
        'trxId': trxId,
        'isProfit': isProfit,
      };

  factory TransactionHistory.fromJson(Map<String, dynamic> json) => TransactionHistory(
        date: DateTime.parse(json['date']),
        amount: (json['amount'] as num).toDouble(),
        paymentMethod: json['paymentMethod'],
        trxId: json['trxId'] ?? '',
        isProfit: json['isProfit'] ?? false,
      );
}

class Member {
  String id;
  String name;
  String mobile;
  String pin;
  double deposit;
  double profitEarned;
  DateTime joinDate;
  List<TransactionHistory> transactions;

  Member({
    required this.id,
    required this.name,
    required this.mobile,
    required this.pin,
    this.deposit = 0.0,
    this.profitEarned = 0.0,
    required this.joinDate,
    required this.transactions,
  });

  double get totalBalance => deposit + profitEarned;

  double get lastDepositAmount {
    var depositTxs = transactions.where((tx) => !tx.isProfit).toList();
    return depositTxs.isNotEmpty ? depositTxs.last.amount : 0.0;
  }

  double get previousDepositAmount {
    return deposit - lastDepositAmount;
  }

  double get expectedTotalTarget {
    DateTime now = DateTime.now();
    double totalExpected = 0.0;

    for (var slab in globalInstallmentSlabs) {
      DateTime effectiveStart = joinDate.isAfter(slab.startDate) ? joinDate : slab.startDate;
      DateTime effectiveEnd = now.isBefore(slab.endDate) ? now : slab.endDate;

      if (effectiveStart.isBefore(effectiveEnd) || effectiveStart.isAtSameMomentAs(effectiveEnd)) {
        int months = (effectiveEnd.year - effectiveStart.year) * 12 + (effectiveEnd.month - effectiveStart.month);
        if (months < 0) months = 0;
        else months += 1;

        totalExpected += (months * slab.amount);
      }
    }
    return totalExpected;
  }

  double get netDifference => expectedTotalTarget - deposit;
  double get dueAmount => netDifference > 0 ? netDifference : 0.0;
  double get advanceAmount => netDifference < 0 ? netDifference.abs() : 0.0;

  int get dueMonthsCount {
    if (dueAmount <= 0 || globalInstallmentSlabs.isEmpty) return 0;
    double currentRate = globalInstallmentSlabs.last.amount;
    return (dueAmount / currentRate).ceil();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'pin': pin,
        'deposit': deposit,
        'profitEarned': profitEarned,
        'joinDate': joinDate.toIso8601String(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'],
        name: json['name'],
        mobile: json['mobile'],
        pin: json['pin'],
        deposit: (json['deposit'] as num).toDouble(),
        profitEarned: (json['profitEarned'] as num).toDouble(),
        joinDate: DateTime.parse(json['joinDate']),
        transactions: (json['transactions'] as List).map((t) => TransactionHistory.fromJson(t)).toList(),
      );
}

List<Member> globalMembers = [];
List<BusinessRecord> globalBusinessRecords = [];

class CloudDatabaseService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> syncAllDataToCloud() async {
    try {
      List<Map<String, dynamic>> membersData = globalMembers.map((m) => m.toJson()).toList();
      await _db.collection('society_data').doc('members').set({'list': membersData});

      List<Map<String, dynamic>> bizData = globalBusinessRecords.map((b) => b.toJson()).toList();
      await _db.collection('society_data').doc('business').set({'list': bizData});

      List<Map<String, dynamic>> slabData = globalInstallmentSlabs.map((s) => s.toJson()).toList();
      await _db.collection('society_data').doc('slabs').set({'list': slabData});

      await _db.collection('society_data').doc('settings').set({
        'societyName': globalSocietyName,
        'adminId': globalAdminId,
        'adminPassword': globalAdminPassword,
      });
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
    }
  }

  static Future<void> loadDataFromCloud() async {
    try {
      var membersDoc = await _db.collection('society_data').doc('members').get().timeout(const Duration(seconds: 5));
      if (membersDoc.exists && membersDoc.data()?['list'] != null) {
        List l = membersDoc.data()!['list'];
        globalMembers = l.map((m) => Member.fromJson(m)).toList();
      }

      var bizDoc = await _db.collection('society_data').doc('business').get().timeout(const Duration(seconds: 5));
      if (bizDoc.exists && bizDoc.data()?['list'] != null) {
        List l = bizDoc.data()!['list'];
        globalBusinessRecords = l.map((b) => BusinessRecord.fromJson(b)).toList();
      }

      var slabDoc = await _db.collection('society_data').doc('slabs').get().timeout(const Duration(seconds: 5));
      if (slabDoc.exists && slabDoc.data()?['list'] != null) {
        List l = slabDoc.data()!['list'];
        globalInstallmentSlabs = l.map((s) => InstallmentSlab.fromJson(s)).toList();
      }

      var settingsDoc = await _db.collection('society_data').doc('settings').get().timeout(const Duration(seconds: 5));
      if (settingsDoc.exists) {
        globalSocietyName = settingsDoc.data()?['societyName'] ?? globalSocietyName;
        globalAdminId = settingsDoc.data()?['adminId'] ?? globalAdminId;
        globalAdminPassword = settingsDoc.data()?['adminPassword'] ?? globalAdminPassword;
      }
    } catch (e) {
      debugPrint("Cloud Load Error or Timeout: $e");
    }
  }
}

class SamobayFinance {
  static double get totalBusinessIncome {
    return globalBusinessRecords.where((r) => r.isIncome).fold(0.0, (sum, item) => sum + item.amount);
  }

  static double get totalBusinessExpense {
    return globalBusinessRecords.where((r) => !r.isIncome).fold(0.0, (sum, item) => sum + item.amount);
  }

  static double get totalProfitDistributed {
    return globalMembers.fold(0.0, (sum, item) => sum + item.profitEarned);
  }

  static double get netProfit {
    double profit = (totalBusinessIncome - totalBusinessExpense) - totalProfitDistributed;
    return profit > 0 ? profit : 0.0;
  }
}

Future<void> saveReportToFile(BuildContext context, String fileName, String content) async {
  try {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final File file = File('${directory?.path}/$fileName');
    await file.writeAsString(content);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ফাইল ডাউনলোডে সেভ হয়েছে:\n${file.path}")),
      );
    }
  } catch (e) {
    final directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory.path}/$fileName');
    await file.writeAsString(content);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ফাইল সেভ হয়েছে: ${file.path}")),
      );
    }
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await CloudDatabaseService.loadDataFromCloud();
    } catch (_) {}

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 15),
            Text("ক্লাউড ব্যাকআপ থেকে লোড হচ্ছে...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isAdmin = true;

  void _handleLogin() {
    String inputId = _idController.text.trim();
    String inputPin = _pinController.text.trim();

    if (_isAdmin) {
      if (inputId == globalAdminId && inputPin == globalAdminPassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ManagerDashboard()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ভুল ম্যানেজার আইডি বা পাসওয়ার্ড!")),
        );
      }
    } else {
      try {
        Member matchedMember = globalMembers.firstWhere(
          (m) => (m.mobile == inputId || m.id == inputId) && m.pin == inputPin,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MemberDashboard(member: matchedMember),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("সঠিক সদস্য আইডি/মোবাইল এবং পিন দিন!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(globalSocietyName),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance, size: 80, color: Colors.green),
                const SizedBox(height: 10),
                Text(
                  globalSocietyName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ToggleButtons(
                  isSelected: [_isAdmin, !_isAdmin],
                  onPressed: (index) {
                    setState(() {
                      _isAdmin = index == 0;
                    });
                  },
                  color: Colors.black,
                  selectedColor: Colors.white,
                  fillColor: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text("ম্যানেজার (অ্যাডমিন)", style: TextStyle(fontSize: 16)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text("সাধারণ সদস্য", style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _idController,
                  decoration: InputDecoration(
                    labelText: _isAdmin ? "ম্যানেজার আইডি" : "সদস্যের মোবাইল বা আইডি",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "পাসওয়ার্ড / পিন",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _handleLogin,
                    child: const Text("লগইন করুন", style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _initialDepositController = TextEditingController();
  DateTime _selectedDate = DateTime(2019, 1, 1);

  double get totalCollection =>
      globalMembers.fold(0.0, (sum, item) => sum + item.deposit);

  double get totalDue =>
      globalMembers.fold(0.0, (sum, item) => sum + item.dueAmount);

  void _showChangeAdminCredentialsDialog() {
    final adminIdController = TextEditingController(text: globalAdminId);
    final adminPassController = TextEditingController(text: globalAdminPassword);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ম্যানেজার আইডি ও পাসওয়ার্ড পরিবর্তন"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adminIdController,
                decoration: const InputDecoration(
                  labelText: "নতুন ম্যানেজার ইউজার আইডি",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adminPassController,
                decoration: const InputDecoration(
                  labelText: "নতুন পাসওয়ার্ড / পিন",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (adminIdController.text.trim().isNotEmpty && adminPassController.text.trim().isNotEmpty) {
                setState(() {
                  globalAdminId = adminIdController.text.trim();
                  globalAdminPassword = adminPassController.text.trim();
                });
                await CloudDatabaseService.syncAllDataToCloud();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("ম্যানেজার আইডি ও পাসওয়ার্ড সফলভাবে আপডেট ও ক্লাউডে সেভ হয়েছে!")),
                  );
                }
              }
            },
            child: const Text("আপডেট করুন"),
          ),
        ],
      ),
    );
  }

  void _showSocietySettingsDialog() {
    final societyNameController = TextEditingController(text: globalSocietyName);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("সমিতির সেটিংস ও কিস্তির স্লাবসমূহ"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: societyNameController,
                      decoration: const InputDecoration(
                        labelText: "সমিতির নাম",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade800),
                      ),
                      onPressed: () {
                        _showChangeAdminCredentialsDialog();
                      },
                      icon: const Icon(Icons.security, size: 18),
                      label: const Text("ম্যানেজার আইডি ও পাসওয়ার্ড পরিবর্তন করুন"),
                    ),
                    const SizedBox(height: 15),
                    const Text("🗓 নির্ধারণকৃত কিস্তির মেয়াদের তালিকা:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    globalInstallmentSlabs.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text("কোনো কিস্তির স্লাব সেট করা নেই। নিচে চাপ দিয়ে যুক্ত করুন।", style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: globalInstallmentSlabs.length,
                            itemBuilder: (context, index) {
                              final slab = globalInstallmentSlabs[index];
                              return Card(
                                color: Colors.green.shade50,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    "মেয়াদ: ${slab.startDate.day}/${slab.startDate.month}/${slab.startDate.year} হতে ${slab.endDate.day}/${slab.endDate.month}/${slab.endDate.year}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text("মাসিক কিস্তি: ৳${slab.amount.toStringAsFixed(0)}"),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.teal, size: 20),
                                        onPressed: () {
                                          _showEditSlabDialog(context, slab, () async {
                                            setDialogState(() {});
                                            setState(() {});
                                            await CloudDatabaseService.syncAllDataToCloud();
                                          });
                                        },
                                        tooltip: "এই স্লাবটি সংশোধন করুন",
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () async {
                                          setDialogState(() {
                                            globalInstallmentSlabs.removeWhere((s) => s.id == slab.id);
                                          });
                                          setState(() {});
                                          await CloudDatabaseService.syncAllDataToCloud();
                                        },
                                        tooltip: "মুছে ফেলুন",
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      onPressed: () {
                        _showAddNewSlabDialog(context, () async {
                          setDialogState(() {});
                          setState(() {});
                          await CloudDatabaseService.syncAllDataToCloud();
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("নতুন মেয়াদের কিস্তি যোগ করুন"),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  if (societyNameController.text.trim().isNotEmpty) {
                    setState(() {
                      globalSocietyName = societyNameController.text.trim();
                    });
                    await CloudDatabaseService.syncAllDataToCloud();
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("সেটিংস সফলভাবে আপডেট ও ক্লাউডে সেভ হয়েছে!")),
                      );
                    }
                  }
                },
                child: const Text("সংরক্ষণ করুন"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSlabDialog(BuildContext context, InstallmentSlab slab, VoidCallback onUpdated) {
    final amountController = TextEditingController(text: slab.amount.toStringAsFixed(0));
    DateTime startDate = slab.startDate;
    DateTime endDate = slab.endDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("কিস্তির মেয়াদ ও রেট সংশোধন"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "মাসিক কিস্তির পরিমাণ (BDT)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text("শুরু: ${startDate.day}/${startDate.month}/${startDate.year}"),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2000), lastDate: DateTime(2040));
                          if (picked != null) setDialogState(() => startDate = picked);
                        },
                        child: const Text("তারিখ দিন"),
                      )
                    ],
                  ),
                  Row(
                    children: [
                      Text("শেষ: ${endDate.day}/${endDate.month}/${endDate.year}"),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: endDate, firstDate: DateTime(2000), lastDate: DateTime(2040));
                          if (picked != null) setDialogState(() => endDate = picked);
                        },
                        child: const Text("তারিখ দিন"),
                      )
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
              ElevatedButton(
                onPressed: () {
                  double? amt = double.tryParse(amountController.text.trim());
                  if (amt != null && amt > 0) {
                    slab.startDate = startDate;
                    slab.endDate = endDate;
                    slab.amount = amt;
                    onUpdated();
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("আপডেট করুন"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddNewSlabDialog(BuildContext context, VoidCallback onAdded) {
    final amountController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime(2035, 12, 31);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("নতুন কিস্তির মেয়াদ যোগ"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "মাসিক কিস্তির পরিমাণ (BDT)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text("শুরু: ${startDate.day}/${startDate.month}/${startDate.year}"),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2000), lastDate: DateTime(2040));
                          if (picked != null) setDialogState(() => startDate = picked);
                        },
                        child: const Text("তারিখ দিন"),
                      )
                    ],
                  ),
                  Row(
                    children: [
                      Text("শেষ: ${endDate.day}/${endDate.month}/${endDate.year}"),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: endDate, firstDate: DateTime(2000), lastDate: DateTime(2040));
                          if (picked != null) setDialogState(() => endDate = picked);
                        },
                        child: const Text("তারিখ দিন"),
                      )
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
              ElevatedButton(
                onPressed: () {
                  double? amt = double.tryParse(amountController.text.trim());
                  if (amt != null && amt > 0) {
                    globalInstallmentSlabs.add(
                      InstallmentSlab(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        startDate: startDate,
                        endDate: endDate,
                        amount: amt,
                      ),
                    );
                    onAdded();
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("যোগ করুন"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddBusinessPostingDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    bool isIncome = true;
    DateTime postingDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("ব্যবসার লাভ/খরচ পোস্টিং"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: isIncome,
                        onChanged: (val) => setDialogState(() => isIncome = val!),
                      ),
                      const Text("ব্যবসার লাভ (+)"),
                      Radio<bool>(
                        value: false,
                        groupValue: isIncome,
                        onChanged: (val) => setDialogState(() => isIncome = val!),
                      ),
                      const Text("প্রজেক্ট খরচ (-)"),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "বিবরণ (যেমন: ৭০ লক্ষ টাকার প্রজেক্ট লাভ)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "টাকার পরিমাণ (BDT)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text("পোস্টিং তারিখ: ${postingDate.day}/${postingDate.month}/${postingDate.year}"),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: postingDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setDialogState(() => postingDate = picked);
                        },
                        child: const Text("তারিখ দিন"),
                      )
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isIncome ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  double? amt = double.tryParse(amountController.text.trim());
                  if (titleController.text.isNotEmpty && amt != null && amt > 0) {
                    setState(() {
                      globalBusinessRecords.add(
                        BusinessRecord(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          amount: amt,
                          isIncome: isIncome,
                          date: postingDate,
                        ),
                      );
                    });
                    await CloudDatabaseService.syncAllDataToCloud();
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("${titleController.text} এর পোস্টিং সফল হয়েছে এবং ক্লাউডে সেভ হয়েছে!")),
                      );
                    }
                  }
                },
                child: const Text("পোস্টিং দিন"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showManageBusinessRecordsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("📊 ব্যবসার লাভ-ক্ষতি খতিয়ান ও রিপোর্ট"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.green.shade50,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("মোট ব্যবসায়িক মুনাফা: ৳${SamobayFinance.totalBusinessIncome.toStringAsFixed(0)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              Text("মোট প্রজেক্ট খরচ: ৳${SamobayFinance.totalBusinessExpense.toStringAsFixed(0)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(),
                          Text("অবশিষ্ট নিট লাভ: ৳${SamobayFinance.netProfit.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("🗓 তারিখভিত্তিক পোস্টিং এর বিস্তারিত তালিকা:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    globalBusinessRecords.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text("এখনো কোনো লাভ বা খরচের পোস্টিং দেওয়া হয়নি।", textAlign: TextAlign.center),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: globalBusinessRecords.length,
                            itemBuilder: (context, index) {
                              final record = globalBusinessRecords[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              record.title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "তারিখ: ${record.date.day}/${record.date.month}/${record.date.year} | ধরন: ${record.isIncome ? 'লাভ (+)' : 'খরচ (-)'}",
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "${record.isIncome ? '+' : '-'}৳${record.amount.toStringAsFixed(0)}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: record.isIncome ? Colors.green : Colors.red,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            onPressed: () async {
                                              setState(() {
                                                globalBusinessRecords.removeWhere((r) => r.id == record.id);
                                              });
                                              await CloudDatabaseService.syncAllDataToCloud();
                                              setDialogState(() {});
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text("${record.title} মুছে ফেলা হয়েছে!")),
                                              );
                                            },
                                            tooltip: "এন্ট্রি ডিলিট করুন",
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("বন্ধ করুন"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  String reportContent = "=== [$globalSocietyName] ব্যবসার লাভ-ক্ষতি খতিয়ান ===\n\n";
                  reportContent += "মোট ব্যবসায়িক মুনাফা: ৳${SamobayFinance.totalBusinessIncome}\n";
                  reportContent += "মোট প্রজেক্ট খরচ: ৳${SamobayFinance.totalBusinessExpense}\n";
                  reportContent += "অবশিষ্ট নিট লাভ: ৳${SamobayFinance.netProfit}\n\n বিস্তারিত এন্ট্রি:\n";
                  for (var r in globalBusinessRecords) {
                    reportContent += "- ${r.title}: ${r.isIncome ? '+' : '-'}৳${r.amount} (${r.date.day}/${r.date.month}/${r.date.year})\n";
                  }
                  await saveReportToFile(context, "Business_Ledger_${DateTime.now().millisecondsSinceEpoch}.txt", reportContent);
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text("ডাউনলোড/সেভ"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _distributeNetProfit() async {
    double netP = SamobayFinance.netProfit;
    double totalDepositCapital = totalCollection;

    if (totalDepositCapital == 0 || netP <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("বণ্টন করার মতো পর্যাপ্ত নিট লাভ নেই!")),
      );
      return;
    }

    setState(() {
      for (var member in globalMembers) {
        double shareRatio = member.deposit / totalDepositCapital;
        double memberProfit = netP * shareRatio;

        member.profitEarned += memberProfit;
        member.transactions.add(
          TransactionHistory(
            date: DateTime.now(),
            amount: memberProfit,
            paymentMethod: 'প্রজেক্ট নিট লাভ বণ্টন (মূলধনের অনুপাতে)',
            isProfit: true,
          ),
        );
      }
    });

    await CloudDatabaseService.syncAllDataToCloud();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("নতুন প্রজেক্টের ৳${netP.toStringAsFixed(2)} লাভ বর্তমান মূলধনের অনুপাতে ন্যায়সংগতভাবে বণ্টন ও ক্লাউডে সেভ সম্পন্ন!")),
      );
    }
  }

  Future<void> _launchSmsApp(String phoneNumber, String message) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: <String, String>{
        'body': message,
      },
    );
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("SMS অ্যাপ ওপেন হয়নি। মেসেজটি ক্লিপবোর্ডে কপি করা হয়েছে।")),
          );
        }
      }
    } catch (e) {
      Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("মেসেজটি ক্লিপবোর্ডে কপি করা হয়েছে।")),
        );
      }
    }
  }

  void _sendSmsDialog(Member member) {
    double todayDeposit = member.lastDepositAmount;
    double totalDeposit = member.deposit;
    double balance = member.totalBalance;
    double due = member.dueAmount;
    double advance = member.advanceAmount;
    double profit = member.profitEarned;

    String dueAdvanceStr = due > 0 
        ? "বকেয়া: ${due.toStringAsFixed(0)}৳ (${member.dueMonthsCount} মাস)" 
        : (advance > 0 ? "অগ্রিম জমা: ${advance.toStringAsFixed(0)}৳" : "বকেয়া: ৳০");

    String smsMessage =
        "[$globalSocietyName]\nপ্রিয় ${member.name},\nআজকে জমা: ${todayDeposit.toStringAsFixed(0)}৳\nমোট মূল জমা: ${totalDeposit.toStringAsFixed(0)}৳\nসর্বমোট ব্যালেন্স: ${balance.toStringAsFixed(0)}৳\n$dueAdvanceStr\nঅর্জিত লাভ: ${profit.toStringAsFixed(0)}৳\nধন্যবাদ!";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${member.name}-কে SMS পাঠান"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("প্রাপক নম্বর: ${member.mobile}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                smsMessage,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: smsMessage));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("মেসেজটি কপি করা হয়েছে!")),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text("কপি করুন"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _launchSmsApp(member.mobile, smsMessage);
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text("সরাসরি SMS"),
          ),
        ],
      ),
    );
  }

  void _showAddInstallmentDialog(Member member) {
    final amountController = TextEditingController();
    final noteController = TextEditingController(text: 'মাসিক কিস্তি জমা');
    DateTime depositDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("${member.name}-এর নতুন কিস্তি জমা"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "নতুন জমার পরিমাণ (BDT)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: "জমার বিবরণ / মাধ্যম",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text("তারিখ: ${depositDate.day}/${depositDate.month}/${depositDate.year}"),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: depositDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              depositDate = picked;
                            });
                          }
                        },
                        child: const Text("তারিখ বদলান"),
                      ),
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  double? amt = double.tryParse(amountController.text.trim());
                  if (amt != null && amt > 0) {
                    setState(() {
                      member.deposit += amt;
                      member.transactions.add(
                        TransactionHistory(
                          date: depositDate,
                          amount: amt,
                          paymentMethod: noteController.text.trim(),
                        ),
                      );
                    });
                    await CloudDatabaseService.syncAllDataToCloud();
                    if (mounted) {
                      Navigator.pop(ctx);
                      _sendSmsDialog(member);
                    }
                  }
                },
                child: const Text("জমা দিন ও SMS পাঠান"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditMemberDialog(Member member) {
    final nameController = TextEditingController(text: member.name);
    final mobileController = TextEditingController(text: member.mobile);
    final depositController = TextEditingController(text: member.deposit.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${member.name}-এর তথ্য সংশোধন"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "নাম")),
            const SizedBox(height: 10),
            TextField(controller: mobileController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "মোবাইল নম্বর")),
            const SizedBox(height: 10),
            TextField(controller: depositController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "মোট জমা সংশোধন")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                member.name = nameController.text.trim();
                member.mobile = mobileController.text.trim();
                member.deposit = double.tryParse(depositController.text) ?? member.deposit;
              });
              await CloudDatabaseService.syncAllDataToCloud();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("সদস্যের তথ্য আপডেট ও ক্লাউডে সেভ হয়েছে!")),
                );
              }
            },
            child: const Text("আপডেট করুন"),
          ),
        ],
      ),
    );
  }

  void _resetPinDialog(Member member) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${member.name}-এর পিন রিসেট"),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "নতুন পিন দিন", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text.trim().isNotEmpty) {
                setState(() {
                  member.pin = pinController.text.trim();
                });
                await CloudDatabaseService.syncAllDataToCloud();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("পিন সফলভাবে আপডেট ও ক্লাউডে সেভ হয়েছে!")),
                  );
                }
              }
            },
            child: const Text("সেভ করুন"),
          ),
        ],
      ),
    );
  }

  void _showMemberStatementDialog(Member member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${member.name}-এর পূর্ণাঙ্গ হিসাব ও ইতিহাস"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("আইডি: ${member.id} | মোবাইল: ${member.mobile}"),
              const Divider(),
              Text("• মূল জমা: ৳${member.deposit.toStringAsFixed(0)}"),
              Text("• অর্জিত লাভ: ৳${member.profitEarned.toStringAsFixed(0)}", style: const TextStyle(color: Colors.blue)),
              Text("• সর্বমোট ব্যালেন্স: ৳${member.totalBalance.toStringAsFixed(0)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              if (member.dueAmount > 0)
                Text("• বকেয়া: ৳${member.dueAmount.toStringAsFixed(0)} (${member.dueMonthsCount} মাস)", style: const TextStyle(color: Colors.red))
              else if (member.advanceAmount > 0)
                Text("• অতিরিক্ত জমা: ৳${member.advanceAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.teal))
              else
                const Text("• বকেয়া: ৳০"),
              const Divider(),
              const Text("🗓 এ পর্যন্ত যতবার ও যত তারিখে কিস্তি/লেনদেন হয়েছে:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
              const SizedBox(height: 6),
              SizedBox(
                height: 180,
                child: member.transactions.isEmpty
                    ? const Center(child: Text("কোনো লেনদেন রেকর্ড নেই।"))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: member.transactions.length,
                        itemBuilder: (context, idx) {
                          final tx = member.transactions[idx];
                          return Card(
                            color: Colors.grey.shade50,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            child: ListTile(
                              dense: true,
                              title: Text("${tx.date.day}/${tx.date.month}/${tx.date.year} — ৳${tx.amount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("${tx.paymentMethod} ${tx.trxId.isNotEmpty ? '(Trx: ${tx.trxId})' : ''}"),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বন্ধ করুন")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              String statementText = "=== [$globalSocietyName] সদস্য স্টেটমেন্ট ===\n\n";
              statementText += "সদস্যের নাম: ${member.name}\nID: ${member.id} | মোবাইল: ${member.mobile}\n";
              statementText += "মূল জমা: ৳${member.deposit}\nঅর্জিত লাভ: ৳${member.profitEarned}\nসর্বমোট ব্যালেন্স: ৳${member.totalBalance}\n";
              statementText += "বকেয়া/অগ্রিম: ${member.dueAmount > 0 ? 'বকেয়া ৳${member.dueAmount}' : 'অগ্রিম ৳${member.advanceAmount}'}\n\nলেনদেনের ইতিহাস:\n";
              for (var t in member.transactions) {
                statementText += "- ${t.date.day}/${t.date.month}/${t.date.year}: ৳${t.amount} (${t.paymentMethod})\n";
              }
              await saveReportToFile(context, "Member_${member.name}_Statement.txt", statementText);
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text("ফাইল ডাউনলোড (TXT)"),
          ),
        ],
      ),
    );
  }

  void _showMemberActionMenu(Member member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${member.name} (ID: ${member.id})",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const Text("কার্যক্রম নির্বাচন করুন", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.green),
              title: const Text("নতুন কিস্তি জমা দিন (+)"),
              onTap: () {
                Navigator.pop(ctx);
                _showAddInstallmentDialog(member);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.teal),
              title: const Text("সদস্যের তথ্য এডিট করুন"),
              onTap: () {
                Navigator.pop(ctx);
                _showEditMemberDialog(member);
              },
            ),
            ListTile(
              leading: const Icon(Icons.vpn_key, color: Colors.orange),
              title: const Text("পিন রিসেট করুন"),
              onTap: () {
                Navigator.pop(ctx);
                _resetPinDialog(member);
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.blue),
              title: const Text("সরাসরি SMS পাঠান"),
              onTap: () {
                Navigator.pop(ctx);
                _sendSmsDialog(member);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.indigo),
              title: const Text("হিসাব ও স্টেটমেন্ট দেখুন/ডাউনলোড"),
              onTap: () {
                Navigator.pop(ctx);
                _showMemberStatementDialog(member);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAllMembersReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("📋 সকল সদস্যের সার্বিক স্টেটমেন্ট (ব্যালেন্স, লাভ ও ডিউ)"),
        content: SizedBox(
          width: double.maxFinite,
          child: globalMembers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("কোনো সদস্যের তথ্য নেই।", textAlign: TextAlign.center),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: globalMembers.length,
                  itemBuilder: (context, index) {
                    final m = globalMembers[index];
                    String dueAdvStr = m.dueAmount > 0
                        ? "Due: ${m.dueAmount.toStringAsFixed(0)}৳ (${m.dueMonthsCount} মাস)"
                        : (m.advanceAmount > 0 ? "Adv: ${m.advanceAmount.toStringAsFixed(0)}৳" : "Due: ৳০");

                    return Card(
                      color: Colors.grey.shade50,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("ID: ${m.id} | নাম: ${m.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("মোবাইল: ${m.mobile}"),
                            const Divider(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("ব্যালেন্স: ৳${m.totalBalance.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                Text("লাভ: ৳${m.profitEarned.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(dueAdvStr, style: TextStyle(fontWeight: FontWeight.bold, color: m.dueAmount > 0 ? Colors.red : Colors.teal)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বন্ধ করুন")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              String allReport = "=== [$globalSocietyName] সকল সদস্যের সমন্বিত স্টেটমেন্ট ===\n\n";
              for (var m in globalMembers) {
                allReport += "ID: ${m.id} | নাম: ${m.name} | মোবাইল: ${m.mobile}\n";
                allReport += "মূল জমা: ৳${m.deposit} | লাভ: ৳${m.profitEarned} | ব্যালেন্স: ৳${m.totalBalance}\n";
                allReport += "বকেয়া/অগ্রিম: ${m.dueAmount > 0 ? 'Due ৳${m.dueAmount}' : 'Adv ৳${m.advanceAmount}'}\n------------------------------------------\n";
              }
              await saveReportToFile(context, "All_Members_Report.txt", allReport);
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text("সকলের স্টেটমেন্ট ডাউনলোড"),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() {
    _nameController.clear();
    _mobileController.clear();
    _initialDepositController.clear();
    _pinController.text = '1234';
    _selectedDate = DateTime(2019, 1, 1);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("সদস্য যুক্ত করুন"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: "সদস্যের নাম")),
                  TextField(controller: _mobileController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "মোবাইল নম্বর")),
                  TextField(controller: _initialDepositController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "মোট জমাকৃত সঞ্চয় (BDT)")),
                  TextField(controller: _pinController, decoration: const InputDecoration(labelText: "পিন/পাসওয়ার্ড (প্রাথমিক)")),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
              ElevatedButton(
                onPressed: () async {
                  if (_nameController.text.trim().isNotEmpty && _mobileController.text.trim().isNotEmpty) {
                    double initDeposit = double.tryParse(_initialDepositController.text.trim()) ?? 0.0;
                    List<TransactionHistory> initTx = [];
                    if (initDeposit > 0) {
                      initTx.add(TransactionHistory(
                        date: _selectedDate,
                        amount: initDeposit,
                        paymentMethod: 'প্রাথমিক সঞ্চয় জমা',
                      ));
                    }

                    setState(() {
                      globalMembers.add(
                        Member(
                          id: (100 + globalMembers.length + 1).toString(),
                          name: _nameController.text.trim(),
                          mobile: _mobileController.text.trim(),
                          pin: _pinController.text.trim(),
                          deposit: initDeposit,
                          joinDate: _selectedDate,
                          transactions: initTx,
                        ),
                      );
                    });
                    await CloudDatabaseService.syncAllDataToCloud();
                    if (mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text("সংরক্ষণ"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(globalSocietyName),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "সমিতির সেটিংস",
            onPressed: _showSocietySettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: "ব্যবসার লাভ/খরচ পোস্টিং",
            onPressed: _showAddBusinessPostingDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "📊 $globalSocietyName - সার্বিক হিসাব",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: _showAddBusinessPostingDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("লাভ পোস্টিং", style: TextStyle(fontSize: 12)),
                      )
                    ],
                  ),
                  const Divider(),
                  Text("• বর্তমান কিস্তি: ৳${globalInstallmentSlabs.isNotEmpty ? globalInstallmentSlabs.last.amount.toStringAsFixed(0) : '0'}/মাস", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                  Text("• মোট সঞ্চয় (মূলধন): $totalCollection টাকা", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text("• মোট ব্যবসায়িক মুনাফা: ${SamobayFinance.totalBusinessIncome} টাকা", style: const TextStyle(fontSize: 14, color: Colors.green)),
                  Text("• মোট প্রজেক্ট খরচ: ${SamobayFinance.totalBusinessExpense} টাকা", style: const TextStyle(fontSize: 14, color: Colors.red)),
                  Text("• মোট বণ্টনকৃত লাভ: ${SamobayFinance.totalProfitDistributed.toStringAsFixed(2)} টাকা", style: const TextStyle(fontSize: 14, color: Colors.purple, fontWeight: FontWeight.bold)),
                  Text("• নিট বণ্টনযোগ্য মুনাফা (অবশিষ্ট): ${SamobayFinance.netProfit.toStringAsFixed(2)} টাকা", style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold)),
                  Text("• মোট বকেয়া (ডিউ): $totalDue টাকা", style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
                          onPressed: _showManageBusinessRecordsDialog,
                          icon: const Icon(Icons.receipt_long, size: 16),
                          label: const Text("লাভ/ক্ষতি খতিয়ান", style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo),
                          onPressed: _showAllMembersReportDialog,
                          icon: const Icon(Icons.people, size: 16),
                          label: const Text("সকলের স্টেটমেন্ট", style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 2)),
                          onPressed: _distributeNetProfit,
                          icon: const Icon(Icons.calculate, size: 14),
                          label: const Text("অটো লাভ", style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("সকল সদস্যের তালিকা (অপশন পেতে ক্লিক করুন):", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            globalMembers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(30.0),
                    child: Center(
                      child: Text("এখনো কোনো সদস্য যোগ করা হয়নি।", style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: globalMembers.length,
                    itemBuilder: (context, index) {
                      final member = globalMembers[index];
                      String dueAdvText = member.dueAmount > 0
                          ? "Due: ${member.dueAmount.toStringAsFixed(0)}৳"
                          : (member.advanceAmount > 0 ? "Adv: ${member.advanceAmount.toStringAsFixed(0)}৳" : "Due: ৳০");

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: InkWell(
                          onTap: () => _showMemberActionMenu(member),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.green,
                                      radius: 14,
                                      child: Text(member.id, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        member.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.touch_app, size: 18, color: Colors.grey),
                                  ],
                                ),
                                const Divider(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "ব্যালেন্স: ${member.totalBalance.toStringAsFixed(0)}৳",
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    Text(
                                      dueAdvText,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: member.dueAmount > 0 ? Colors.red : Colors.teal,
                                      ),
                                    ),
                                    Text(
                                      "লাভ: ${member.profitEarned.toStringAsFixed(0)}৳",
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("সদস্য যুক্ত করুন", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class MemberDashboard extends StatefulWidget {
  final Member member;
  const MemberDashboard({super.key, required this.member});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _trxController = TextEditingController();
  String _selectedMethod = 'bKash';

  void _showChangePinDialog() {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("আপনার পিন পরিবর্তন করুন"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "বর্তমান পিন", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "নতুন পিন", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
          ElevatedButton(
            onPressed: () async {
              if (oldPinController.text == widget.member.pin) {
                if (newPinController.text.trim().isNotEmpty) {
                  setState(() {
                    widget.member.pin = newPinController.text.trim();
                  });
                  await CloudDatabaseService.syncAllDataToCloud();
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("আপনার পিন সফলভাবে পরিবর্তন ও ক্লাউডে সেভ হয়েছে!")),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("বর্তমান পিন সঠিক নয়!")),
                );
              }
            },
            child: const Text("পরিবর্তন করুন"),
          ),
        ],
      ),
    );
  }

  void _showDepositDialog() {
    _amountController.clear();
    _trxController.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("অনলাইন জমার মাধ্যম বিবরণ"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("পেমেন্ট মাধ্যম বেছে নিন:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'bKash',
                        groupValue: _selectedMethod,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              _selectedMethod = val;
                            });
                          }
                        },
                      ),
                      const Text("bKash"),
                      const SizedBox(width: 15),
                      Radio<String>(
                        value: 'Bank',
                        groupValue: _selectedMethod,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              _selectedMethod = val;
                            });
                          }
                        },
                      ),
                      const Text("সোনালী ব্যাংক"),
                    ],
                  ),
                  const Divider(),
                  if (_selectedMethod == 'bKash') ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.pink.shade50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("বিকাশ পার্সোনাল (Send Money):", style: TextStyle(fontSize: 12, color: Colors.pink, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              const SelectableText("01728021804", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20, color: Colors.pink),
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: "01728021804"));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("বিকাশ নম্বর কপি করা হয়েছে!")),
                                  );
                                },
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.blue.shade50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("সোনালী ব্যাংক পিএলসি:", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                          const Text("অ্যাকাউন্ট নম্বর:", style: TextStyle(fontSize: 12)),
                          Row(
                            children: [
                              const SelectableText("0204801010355", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20, color: Colors.blue),
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: "0204801010355"));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("ব্যাংক অ্যাকাউন্ট নম্বর কপি করা হয়েছে!")),
                                  );
                                },
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "টাকার পরিমাণ (BDT)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _trxController,
                    decoration: InputDecoration(
                      labelText: _selectedMethod == 'bKash' ? "bKash TrxID (ট্রানজেকশন আইডি)" : "ডিপোজিট স্লিপ / ট্রানজেকশন নম্বর",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("বাতিল")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedMethod == 'bKash' ? Colors.pink : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  double? amount = double.tryParse(_amountController.text.trim());
                  if (amount != null && amount > 0 && _trxController.text.isNotEmpty) {
                    setState(() {
                      widget.member.deposit += amount;
                      widget.member.transactions.add(
                        TransactionHistory(
                          date: DateTime.now(),
                          amount: amount,
                          paymentMethod: _selectedMethod == 'bKash' ? 'bKash Send Money' : 'সোনালী ব্যাংক',
                          trxId: _trxController.text.trim(),
                        ),
                      );
                    });
                    await CloudDatabaseService.syncAllDataToCloud();
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("৳$amount টাকা সঞ্চয় জমা হিসেবে রেকর্ড ও ক্লাউডে সেভ হয়েছে!")),
                      );
                    }
                  }
                },
                child: const Text("জমা কনফার্ম করুন"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(globalSocietyName),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key),
            tooltip: "পিন পরিবর্তন",
            onPressed: _showChangePinDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("👤 ${widget.member.name}-এর খতিয়ান", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.green)),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: _showChangePinDialog,
                        icon: const Icon(Icons.lock_reset, size: 16),
                        label: const Text("পিন বদলান", style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text("• সদস্য আইডি: ${widget.member.id}", style: const TextStyle(fontSize: 15)),
                  Text("• মূল সঞ্চয় (কিস্তি জমা): ৳${widget.member.deposit.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text("• অর্জিত মোট লাভ: ৳${widget.member.profitEarned.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                  Text("• সর্বমোট ব্যালেন্স: ৳${widget.member.totalBalance.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                  const Divider(),
                  if (widget.member.dueAmount > 0)
                    Text("• বকেয়া কিস্তি (${widget.member.dueMonthsCount} মাসের হিসাবে): ৳${widget.member.dueAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, color: Colors.red, fontWeight: FontWeight.bold))
                  else if (widget.member.advanceAmount > 0)
                    Text("• অতিরিক্ত জমা (Advance): ৳${widget.member.advanceAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, color: Colors.teal, fontWeight: FontWeight.bold))
                  else
                    const Text("• বকেয়া: ৳০ (পরিশোধিত)", style: TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
                onPressed: _showDepositDialog,
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text("অনলাইনে কিস্তি জমা দিন (bKash / Bank)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("🗓 আপনার জমা ও লাভের হিসাবের ইতিহাস:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: widget.member.transactions.isEmpty
                  ? const Center(child: Text("এখনো কোনো জমা এন্ট্রি হয়নি।"))
                  : ListView.builder(
                      itemCount: widget.member.transactions.length,
                      itemBuilder: (context, index) {
                        final tx = widget.member.transactions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: tx.isProfit ? Colors.blue : (tx.paymentMethod.contains('bKash') ? Colors.pink : Colors.green),
                              child: Icon(tx.isProfit ? Icons.trending_up : Icons.attach_money, color: Colors.white),
                            ),
                            title: Text("${tx.isProfit ? 'লাভ যোগ:' : 'জমা:'} ৳${tx.amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("তারিখ: ${tx.date.day}/${tx.date.month}/${tx.date.year} | মাধ্যম: ${tx.paymentMethod}"),
                            trailing: tx.trxId.isNotEmpty ? Text("ID: ${tx.trxId}", style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  String memberText = "=== [$globalSocietyName] সদস্য স্টেটমেন্ট ===\n\n";
                  memberText += "নাম: ${widget.member.name} (ID: ${widget.member.id})\n";
                  memberText += "মোবাইল: ${widget.member.mobile}\n";
                  memberText += "মূল জমা: ৳${widget.member.deposit}\n";
                  memberText += "অর্জিত লাভ: ৳${widget.member.profitEarned}\n";
                  memberText += "সর্বমোট ব্যালেন্স: ৳${widget.member.totalBalance}\n\nলেনদেনসমূহ:\n";
                  for (var t in widget.member.transactions) {
                    memberText += "- ${t.date.day}/${t.date.month}/${t.date.year}: ৳${t.amount} (${t.paymentMethod})\n";
                  }
                  await saveReportToFile(context, "${widget.member.name}_Statement.txt", memberText);
                },
                icon: const Icon(Icons.download),
                label: const Text(
                  "বিস্তারিত স্টেটমেন্ট ডাউনলোড করুন (ফাইল সেভ)",
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}