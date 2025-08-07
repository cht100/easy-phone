// lib/app.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contacts App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ContactsPage(),
    );
  }
}

class ContactsPage extends StatefulWidget {
  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> contacts = [];
  bool permissionDenied = false;
  bool permissionRequested = false;
  FlutterTts flutterTts = FlutterTts();

  // 新增：用于文本输入的控制器
  final TextEditingController _textController = TextEditingController();
  // 新增：默认文本
  String _defaultText = "你好，这是一个测试文本";

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _requestPermissionAndFetchContacts();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  _initializeTts() async {
    try {
      bool isAvailable = await flutterTts.isLanguageAvailable("zh-CN");
      print('TTS language available: $isAvailable');
    } catch (e) {
      print('Error checking TTS availability: $e');
    }
  }

  _requestPermissionAndFetchContacts() async {
    // 请求联系人权限
    var status = await Permission.contacts.request();

    if (status.isGranted) {
      // 获取真实联系人
      await _fetchContacts();
      setState(() {
        permissionDenied = false;
        permissionRequested = true;
      });
    } else if (status.isPermanentlyDenied) {
      // 权限被永久拒绝
      setState(() {
        permissionDenied = true;
        permissionRequested = true;
      });
    } else {
      // 权限被拒绝
      setState(() {
        permissionDenied = true;
        permissionRequested = true;
      });
    }
  }

  // 获取真实联系人
  _fetchContacts() async {
    try {
      List<Contact> contactsStream = await FlutterContacts.getContacts(withProperties: true);
      setState(() {
        contacts = contactsStream;
      });
    } catch (e) {
      print("获取联系人失败: $e");
      setState(() {
        contacts = [];
      });
    }
  }

  // 修改 _speak 方法，添加初始化检查
  _speak(String text) async {
    print('Speaking: $text');

    try {
      // 等待 TTS 引擎初始化完成
      await flutterTts.awaitSpeakCompletion(true);

      // 设置 TTS 参数
      await flutterTts.setLanguage("zh-CN");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setPitch(1.0);
      await flutterTts.setVolume(1.0);

      // 朗读文本
      print('Attempting to speak: $text');
      await flutterTts.speak(text);
      print('Speak command sent successfully');
    } catch (e) {
      print('Error speaking: $e');
    }
  }

  // 新增：读取输入框中的文本
  _speakInputText() {
    String textToSpeak = _textController.text.isEmpty
        ? _defaultText
        : _textController.text;
    _speak(textToSpeak);
  }

  _launchPhone(String phoneNumber) async {
    // 清理电话号码，移除空格、横线等字符
    String cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanPhoneNumber,
    );
    print('Launching phone: $launchUri');
    // 直接拨打电话
    bool? result = await launchUrl(launchUri);
    if (result == false) {
      // 如果无法直接拨打，显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法拨打该号码: $phoneNumber')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('联系人',style: TextStyle(fontSize: 40),),
      ),
      body: !permissionRequested
          ? Center(
        child: CircularProgressIndicator(),
      )
          : permissionDenied
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('需要联系人权限才能显示联系人列表'),
            ElevatedButton(
              onPressed: _requestPermissionAndFetchContacts,
              child: Text('重新请求权限'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            child: contacts.isEmpty
                ? Center(
              child: Text('暂无联系人'),
            )
                : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                Contact contact = contacts[index];
                return ContactItem(
                  contact: contact,
                  onTap: (name) => _speak(name), // 传递函数引用
                  onCall: (number) => _launchPhone(number), // 同样修改这里
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ContactItem extends StatefulWidget {
  final Contact contact;
  final Function(String) onTap;
  final Function(String) onCall;

  ContactItem({
    required this.contact,
    required this.onTap,
    required this.onCall,
  });

  @override
  _ContactItemState createState() => _ContactItemState();
}

class _ContactItemState extends State<ContactItem> {
  bool isSpeaking = false;

  // 处理按下事件
  _handleTapDown() {
    setState(() {
      isSpeaking = true; // 按下时设为true，显示灰色背景
    });
  }

  // 处理抬起事件
  _handleTapUp() {
    setState(() {
      isSpeaking = false; // 松开时设为false，恢复白色背景
    });
  }

  // 处理取消事件
  _handleTapCancel() {
    setState(() {
      isSpeaking = false; // 取消时也设为false，恢复白色背景
    });
  }

  _handleTap() {
    String displayName = widget.contact.displayName ?? '未知联系人';
    widget.onTap(displayName);
  }

  @override
  Widget build(BuildContext context) {
    String displayName = widget.contact.displayName ?? '未知联系人';

    // 获取第一个电话号码
    String? phoneNumber = '无电话';
    if (widget.contact.phones.isNotEmpty) {
      phoneNumber = widget.contact.phones.first.number;
    }

    return Column(
      children: [
        Container(
          color: isSpeaking ? Colors.grey[300] : Colors.white, // 根据isSpeaking状态改变背景色
          child: GestureDetector(
            onTap: _handleTap, // 点击事件
            onTapDown: (_) => _handleTapDown(), // 按下事件
            onTapUp: (_) => _handleTapUp(), // 松开事件
            onTapCancel: _handleTapCancel, // 取消事件
            child: ListTile(
              title: Text(displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 34)),
              subtitle: Text(phoneNumber, style: TextStyle(fontSize: 16)),
              trailing: phoneNumber != '无电话'
                  ? CircleAvatar(
                backgroundColor: Colors.grey[100], // 灰色背景
                radius: 40,
                child: IconButton(
                  icon: Icon(Icons.phone, color: Colors.green, size: 40),
                  onPressed: () => widget.onCall(phoneNumber!),
                ),
              )
                  : null,
            ),
          ),
        ),
        Divider(
          color: Colors.grey, // 黑色分割线
          height: 1, // 分割线高度
          thickness: 2, // 分割线粗细
        ),
      ],
    );
  }
}
