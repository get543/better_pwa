import 'dart:convert'; // Required for JSON encoding/decoding
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // save links to device
import 'package:better_pwa/screens/webview.dart';
import 'package:better_pwa/models/link_items.dart';
import 'package:better_pwa/services/app.updater.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Removed 'final' so we can reassign the list when loading from storage
  List<LinkItem> _customLinks = [];

  // NEW: Track loading state to prevent UI glitches
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLinks(); // Load data as soon as the screen opens

    // Wait for the UI to render before showing the dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdater.checkForUpdates(context);
    });
  }

  // --- NEW: LOAD FROM STORAGE ---
  Future<void> _loadLinks() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final List<String>? savedLinks = prefs.getStringList('custom_links') ?? prefs.getStringList('custom_links_backup');

      if (savedLinks != null) {
        final loadedLinks = <LinkItem>[];

        for (final entry in savedLinks) {
          final decoded = jsonDecode(entry);
          if (decoded is Map) {
            loadedLinks.add(LinkItem.fromJson(Map<String, dynamic>.from(decoded)));
          }
        }

        _customLinks = loadedLinks;
      }
    } catch (e) {
      debugPrint('Failed to load custom links: $e');
      _customLinks = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- NEW: SAVE TO STORAGE ---
  Future<void> _saveLinks() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> linkStrings = _customLinks.map((item) {
      return jsonEncode(item.toJson());
    }).toList();

    await prefs.setStringList('custom_links', linkStrings);
    await prefs.setStringList('custom_links_backup', linkStrings);
  }

  Future<void> _restoreBackupLinks() async {
    final rootContext = context;
    final messenger = ScaffoldMessenger.maybeOf(rootContext);

    final prefs = await SharedPreferences.getInstance();
    final backupLinks = prefs.getStringList('custom_links_backup');

    if (backupLinks == null || backupLinks.isEmpty) {
      if (rootContext.mounted && messenger != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No backup available yet.')),
        );
      }
      return;
    }

    final restoredLinks = <LinkItem>[];

    try {
      for (final entry in backupLinks) {
        final decoded = jsonDecode(entry);
        if (decoded is Map) {
          restoredLinks.add(LinkItem.fromJson(Map<String, dynamic>.from(decoded)));
        }
      }
    } catch (e) {
      debugPrint('Failed to restore custom links from backup: $e');
      if (rootContext.mounted && messenger != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Backup data is invalid and could not be restored.')),
        );
      }
      return;
    }

    setState(() {
      _customLinks = restoredLinks;
      _isLoading = false;
    });

    await _saveLinks();

    if (rootContext.mounted && messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Restored ${restoredLinks.length} saved website${restoredLinks.length == 1 ? '' : 's'}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: AppBar(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                title: Text(widget.title),
                actions: [
                  Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.history),
                        tooltip: 'Restore backup',
                        onPressed: _restoreBackupLinks,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add website',
                        onPressed: _showAddWebsiteDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // NEW: Show a loading spinner while fetching from storage
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            // Handle the Empty State vs Populated List
            else if (_customLinks.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No websites added yet.\nClick the + button to add one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: _customLinks.length,
                  itemBuilder: (context, index) {
                    final item = _customLinks[index];

                    // 1. Wrap in Padding to handle the gap between cards
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),

                      // 2. Wrap in Dismissible for the swipe action
                      child: Dismissible(
                        // Every Dismissible needs a unique Key to track items
                        key: ValueKey(item.url),
                        direction: DismissDirection.endToStart,
                        // Only allow swiping Right-to-Left

                        // This is the red background revealed when swiping
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),

                        // What happens when the swipe is completed
                        onDismissed: (direction) async {
                          // Remove from UI state
                          setState(() {
                            _customLinks.removeAt(index);
                          });

                          // Save the updated list to local device storage
                          await _saveLinks();

                          // Show a quick confirmation SnackBar
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${item.title} removed')),
                            );
                          }
                        },

                        // The actual Card UI
                        child: Card(
                          elevation: 4.0,
                          margin: EdgeInsets.zero,
                          // Margin moved to the Padding wrapper above!
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => CommonWebView(
                                    url: item.url,
                                    title: item.title,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(15.0),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30.0,
                                    backgroundColor: Colors.blueAccent.shade100,
                                    child: Text(
                                      item.title.isNotEmpty ? item.title[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20.0),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 18.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          item.url,
                                          style: const TextStyle(
                                            fontSize: 14.0,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddWebsiteDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Website'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Website Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL (e.g., google.com)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                  String url = urlController.text.trim();

                  if (!url.startsWith('http://') && !url.startsWith('https://')) {
                    url = 'https://$url';
                  }

                  setState(() {
                    _customLinks.add(
                      LinkItem(
                        title: titleController.text.trim(),
                        url: url,
                        imageUrl: '',
                      ),
                    );
                  });

                  // Save to device storage immediately after adding
                  await _saveLinks();

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
