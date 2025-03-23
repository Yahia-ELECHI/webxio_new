import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../services/preferences_service.dart';
import 'fullscreen_cagnotte.dart';

class CagnotteWebView extends StatefulWidget {
  final String title;
  final VoidCallback? onSeeAllPressed;

  const CagnotteWebView({
    Key? key,
    required this.title,
    this.onSeeAllPressed,
  }) : super(key: key);

  @override
  State<CagnotteWebView> createState() => _CagnotteWebViewState();
}

class _CagnotteWebViewState extends State<CagnotteWebView> {
  final PreferencesService _preferencesService = PreferencesService();
  WebViewController? _controller;
  String _currentUrl = '';
  bool _isLoading = true;
  bool _isEditing = false;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    setState(() {
      _isLoading = true;
    });

    final url = await _preferencesService.getCagnotteUrl();
    _currentUrl = url;
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });

            // Optimiser l'affichage pour le mobile et activer le défilement
            _controller!.runJavaScript('''
              document.querySelector('meta[name="viewport"]').content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
              
              // Style pour permettre le défilement
              var css = 'html, body { height: auto !important; overflow: auto !important; overflow-y: auto !important; }';
              css += '* { -webkit-overflow-scrolling: touch !important; touch-action: auto !important; }';
              css += 'div, section, article { height: auto !important; overflow: auto !important; }';
              
              // Styles spécifiques pour faciliter le défilement avec la souris
              css += '::-webkit-scrollbar { width: 8px; background-color: rgba(0,0,0,0.1); }';
              css += '::-webkit-scrollbar-thumb { background-color: rgba(0,0,0,0.3); border-radius: 4px; }';
              css += '::-webkit-scrollbar-thumb:hover { background-color: rgba(0,0,0,0.5); }';
              css += 'body { cursor: grab; }';
              
              var style = document.createElement('style');
              style.type = 'text/css';
              style.appendChild(document.createTextNode(css));
              document.head.appendChild(style);
              
              // Empêcher les éléments de bloquer le défilement
              document.addEventListener('touchmove', function(e) {
                e.stopPropagation();
              }, { passive: true });
              
              // Activer le défilement à la souris
              document.addEventListener('wheel', function(e) {
                e.stopPropagation();
              }, { passive: true });
              
              // S'assurer que tous les éléments sont défilables
              var elements = document.querySelectorAll('body, div, section, article');
              for (var i = 0; i < elements.length; i++) {
                elements[i].style.overflow = 'auto';
                elements[i].style.height = 'auto';
                elements[i].style.maxHeight = 'none';
                elements[i].style.webkitOverflowScrolling = 'touch';
                elements[i].style.touchAction = 'auto';
                elements[i].style.cursor = 'grab';
              }
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            // print('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _isLoading = false;
    });
  }

  void _showConfigDialog() {
    _urlController.text = _currentUrl;
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _saveUrl() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isNotEmpty && Uri.parse(newUrl).isAbsolute) {
      await _preferencesService.setCagnotteUrl(newUrl);
      setState(() {
        _isEditing = false;
        _currentUrl = newUrl;
      });
      _controller!.loadRequest(Uri.parse(newUrl));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une URL valide')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.fullscreen, size: 20),
                      onPressed: () {
                        if (_controller != null && !_isLoading) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FullscreenCagnotte(
                                url: _currentUrl,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez patienter pendant le chargement...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      tooltip: 'Voir en plein écran',
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, size: 20),
                      onPressed: _showConfigDialog,
                      tooltip: 'Configurer l\'URL',
                    ),
                    if (widget.onSeeAllPressed != null)
                      TextButton(
                        onPressed: widget.onSeeAllPressed,
                        child: const Text('Voir tout'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isEditing
                  ? _buildUrlConfigForm()
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: _buildWebViewContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewContent() {
    // Version adaptative de l'interface en fonction de la plateforme
    // Plus robuste et optimisée pour tous les environnements
    bool isEmulator = false;
    try {
      // Détection des environnements d'émulateur (approx.)
      isEmulator = !kReleaseMode && !Platform.isIOS && Platform.isAndroid;
    } catch (e) {
      // Fallback si la détection échoue
      isEmulator = false;
    }

    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (isEmulator) {
      // Version optimisée pour l'émulateur et les tests avec souris
      return Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (_) => true,  // Bloquer la propagation des notifications
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.8, // Augmenter la hauteur pour afficher plus de contenu
                      child: WebViewWidget(controller: _controller!),
                    ),
                  ),
                ),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          // Guide d'utilisation avec interface adaptée à l'émulateur
          
        ],
      );
    } else {
      // Version optimisée pour les appareils réels avec écran tactile
      return Stack(
        children: [
          GestureDetector(
            // Capture des gestes tactiles
            onVerticalDragUpdate: (_) {},
            onHorizontalDragUpdate: (_) {},
            behavior: HitTestBehavior.translucent,
            child: WebViewWidget(controller: _controller!),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      );
    }
  }

  Widget _buildUrlConfigForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configuration de la cagnotte en ligne',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Entrez l\'URL de votre cagnotte en ligne (ex: Leetchi, Lydia, etc.)',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'https://www.example.com/cagnotte',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                });
              },
              child: const Text('Annuler'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _saveUrl,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ],
    );
  }
}
