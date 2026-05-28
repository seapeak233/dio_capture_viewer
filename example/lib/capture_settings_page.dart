import 'package:dio_capture_viewer/dio_capture_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExampleCaptureSettingsPage extends StatefulWidget {
  const ExampleCaptureSettingsPage({required this.store, this.host, super.key});

  final CaptureStore store;
  final String? host;

  @override
  State<ExampleCaptureSettingsPage> createState() =>
      _ExampleCaptureSettingsPageState();
}

class _ExampleCaptureSettingsPageState
    extends State<ExampleCaptureSettingsPage> {
  late final TextEditingController _cacheSizeController;

  @override
  void initState() {
    super.initState();
    _cacheSizeController = TextEditingController(
      text: widget.store.maxCacheSize.toString(),
    );
  }

  @override
  void dispose() {
    _cacheSizeController.dispose();
    super.dispose();
  }

  void _applyCacheSize() {
    final size = int.tryParse(_cacheSizeController.text.trim());
    if (size != null) {
      widget.store.setMaxCacheSize(size);
    }
    _cacheSizeController.text = widget.store.maxCacheSize.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dio Capture Settings')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.host != null) ...[
                Text(
                  'Current host',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(widget.host!),
                const SizedBox(height: 24),
              ],
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Capture requests'),
                subtitle: Text(
                  widget.store.isEnabled
                      ? 'Requests are being recorded.'
                      : 'Requests and responses are not recorded.',
                ),
                value: widget.store.isEnabled,
                onChanged: widget.store.setEnabled,
              ),
              const SizedBox(height: 16),
              Text(
                'Max cached requests',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cacheSizeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _applyCacheSize(),
                      decoration: const InputDecoration(
                        hintText:
                            '${CaptureStore.minCacheSize} - ${CaptureStore.maxCacheSizeLimit}',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _applyCacheSize,
                    child: const Text('Apply'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: widget.store.togglePanel,
                child: const Text('Toggle viewer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
