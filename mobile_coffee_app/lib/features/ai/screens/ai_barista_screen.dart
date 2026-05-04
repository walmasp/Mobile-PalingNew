import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../data/services/menu_service.dart';
import '../../../controllers/auth_controller.dart'; 

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class AiBaristaScreen extends StatefulWidget {
  const AiBaristaScreen({super.key});

  @override
  State<AiBaristaScreen> createState() => _AiBaristaScreenState();
}

class _AiBaristaScreenState extends State<AiBaristaScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthController _authController = AuthController();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late ChatSession _chatSession;
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    _initializeKopiBot();
  }

  Future<void> _initializeKopiBot() async {
    setState(() => _isLoading = true);

    String userName = "Pelanggan";
    String contextMenu = "Data menu tidak tersedia.";

    try {
      // 1. Ambil Nama User
      String? storedName = await _authController.getLoggedInUserName();
      if (storedName != null) userName = storedName;

      // 2. Ambil Data Menu dari Database (Cafe ID 1 sebagai contoh)
      final menuData = await MenuService.getMenus(1);
      if (menuData.isNotEmpty) {
        contextMenu = menuData.map((m) {
          return "- **${m['nama_menu']}** | Harga: Rp${m['harga']} | Deskripsi: ${m['deskripsi'] ?? '-'}";
        }).join("\n");
      }
    } catch (e) {
      print("Error initialization: $e");
    }

    // 3. Konfigurasi AI dengan Context Database & User
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(
        "Kamu adalah 'KopiBot', barista AI yang gaul, ramah, dan ahli kopi.\n"
        "Nama pelanggan yang bicara denganmu adalah: $userName.\n\n"
        "BERIKUT ADALAH DAFTAR MENU ASLI DI CAFE KAMI:\n"
        "$contextMenu\n\n"
        "TUGAS & ATURAN:\n"
        "- Gunakan format Markdown (**Bold**, List) agar cantik.\n"
        "- HANYA rekomendasikan menu yang ada di daftar atas.\n"
        "- Jika ditanya menu di luar daftar, jawab bahwa menu itu belum tersedia.\n"
        "- Ajak user bercanda tipis khas barista agar suasana akrab."
      ),
    );

    _chatSession = model.startChat();

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: "Halo **$userName**! 👋 Aku **KopiBot**. Aku sudah cek daftar menu kita hari ini. Mau aku kasih rekomendasi kopi yang cocok buat mood kamu?",
        isUser: false,
      ));
      _isLoading = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      if (!mounted) return;

      setState(() {
        _messages.add(ChatMessage(text: response.text ?? "Maaf, aku bingung..", isUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: "Waduh, mesin kopinya macet (Error)! Coba lagi ya. ☕", isUser: false));
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("KopiBot AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Chat List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildChatBubble(_messages[index]),
            ),
          ),

          // Loading Indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text("KopiBot sedang meracik jawaban...", 
                style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
            ),

          // Input Area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(25)),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Tanya soal menu...",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: const Icon(Icons.send_rounded, color: Colors.brown),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    bool isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF4E342E) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: MarkdownBody(
          data: message.text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: isUser ? Colors.white : Colors.white70, fontSize: 14),
            strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
