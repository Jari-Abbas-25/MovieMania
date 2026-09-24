// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../core/bridge/moviebox_bridge.dart';
import '../core/models/media_models.dart';
import '../core/player/player_launcher.dart';
import '../theme/app_theme.dart';

enum PlaybackSelectionStep {
  audio,
  loadingStreams,
  subtitles,
  quality,
  resolving,
  error,
}

class QualityOption {
  final String quality;
  final ReleaseSource release;

  QualityOption({required this.quality, required this.release});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QualityOption &&
          runtimeType == other.runtimeType &&
          quality.toLowerCase() == other.quality.toLowerCase() &&
          release == other.release;

  @override
  int get hashCode => quality.toLowerCase().hashCode ^ release.hashCode;
}

class PlaybackSelectionModal extends StatefulWidget {
  final String provider;
  final String mediaId;
  final String title;
  final int season;
  final int episode;
  final List<AudioTrackInfo> dubs;
  final TargetPlayer defaultPlayer;

  const PlaybackSelectionModal({
    super.key,
    required this.provider,
    required this.mediaId,
    required this.title,
    this.season = 0,
    this.episode = 0,
    this.dubs = const [],
    this.defaultPlayer = TargetPlayer.chooser,
  });

  static Future<void> show({
    required BuildContext context,
    required String provider,
    required String mediaId,
    required String title,
    int season = 0,
    int episode = 0,
    List<AudioTrackInfo> dubs = const [],
    TargetPlayer defaultPlayer = TargetPlayer.chooser,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(color: AppColors.cardBorder, width: 1),
                left: BorderSide(color: AppColors.cardBorder, width: 1),
                right: BorderSide(color: AppColors.cardBorder, width: 1),
              ),
            ),
            child: PlaybackSelectionModal(
              provider: provider,
              mediaId: mediaId,
              title: title,
              season: season,
              episode: episode,
              dubs: dubs,
              defaultPlayer: defaultPlayer,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<PlaybackSelectionModal> createState() => _PlaybackSelectionModalState();
}

class _PlaybackSelectionModalState extends State<PlaybackSelectionModal> {
  PlaybackSelectionStep _currentStep = PlaybackSelectionStep.audio;
  String? _errorMessage;

  AudioTrackInfo? _selectedAudio;
  List<ReleaseSource> _availableReleases = [];
  ReleaseSource? _selectedRelease;
  List<SubtitleTrackInfo> _availableSubtitles = [];
  SubtitleTrackInfo? _selectedSubtitle; // null = Off
  QualityOption? _selectedQualityOption;

  List<QualityOption> get _availableQualityOptions {
    final list = <QualityOption>[];
    for (final release in _availableReleases) {
      if (release.qualities.isNotEmpty) {
        for (final q in release.qualities) {
          if (q.toLowerCase() != 'multi') {
            list.add(QualityOption(quality: q, release: release));
          }
        }
      } else {
        final q = (release.quality != null &&
                release.quality!.isNotEmpty &&
                release.quality!.toLowerCase() != 'multi')
            ? release.quality!
            : '1080p';
        list.add(QualityOption(quality: q, release: release));
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _initFlow();
  }

  void _initFlow() {
    if (widget.dubs.length > 1) {
      _currentStep = PlaybackSelectionStep.audio;
      _selectedAudio = widget.dubs.first;
    } else {
      if (widget.dubs.isNotEmpty) {
        _selectedAudio = widget.dubs.first;
      }
      _fetchStreamsAndSubtitles();
    }
  }

  String get _activeSubjectId {
    return _selectedAudio?.subjectId.isNotEmpty == true
        ? _selectedAudio!.subjectId
        : widget.mediaId;
  }

  Future<void> _fetchStreamsAndSubtitles() async {
    setState(() {
      _currentStep = PlaybackSelectionStep.loadingStreams;
      _errorMessage = null;
    });

    try {
      final subjectId = _activeSubjectId;

      final streamRes = await MovieBoxBridge.episodeStreams(
        provider: widget.provider,
        id: subjectId,
        season: widget.season,
        episode: widget.episode,
      );

      if (streamRes['success'] != true ||
          streamRes['releases'] == null ||
          (streamRes['releases'] as List).isEmpty) {
        if (mounted) {
          setState(() {
            _currentStep = PlaybackSelectionStep.error;
            _errorMessage = streamRes['error']?.toString() ??
                'No streaming releases found for this audio track.';
          });
        }
        return;
      }

      final rawReleases = streamRes['releases'] as List;
      final releases = rawReleases
          .map((r) => ReleaseSource.fromJson(
              r as Map<String, dynamic>, widget.provider))
          .toList();

      _availableReleases = releases;
      _selectedRelease = releases.first;
      final qualOpts = _availableQualityOptions;
      if (qualOpts.isNotEmpty) {
        _selectedQualityOption = qualOpts.first;
      }

      // Fetch captions
      final resourceId = releases.first.resourceId ?? '';
      final siblingIds = widget.dubs
          .map((d) => d.subjectId)
          .where((id) => id.isNotEmpty)
          .toList();

      try {
        final captionsRes = await MovieBoxBridge.getCaptions(
          subjectId: subjectId,
          resourceId: resourceId,
          siblingIds: siblingIds,
          season: widget.season,
          episode: widget.episode,
        );

        if (captionsRes['success'] == true &&
            captionsRes['captions'] is List) {
          final rawCaptions = captionsRes['captions'] as List;
          _availableSubtitles = rawCaptions
              .map((c) =>
                  SubtitleTrackInfo.fromJson(c as Map<String, dynamic>))
              .where((c) => c.url.isNotEmpty)
              .toList();
        } else {
          _availableSubtitles = [];
        }
      } catch (_) {
        _availableSubtitles = [];
      }

      if (mounted) {
        setState(() {
          _currentStep = PlaybackSelectionStep.subtitles;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStep = PlaybackSelectionStep.error;
          _errorMessage = 'Failed to load playback options: $e';
        });
      }
    }
  }

  Future<void> _resolveAndPlay() async {
    if (_selectedRelease == null) return;

    setState(() {
      _currentStep = PlaybackSelectionStep.resolving;
      _errorMessage = null;
    });

    try {
      final res = await MovieBoxBridge.resolveStream(
        provider: widget.provider,
        release: _selectedRelease!.rawJson,
      );

      if (res['success'] == true && res['source'] != null) {
        final rawSource = res['source'] as Map<String, dynamic>;

        if (_selectedSubtitle != null) {
          rawSource['subtitle'] = _selectedSubtitle!.url;
        }

        final source = PlaybackSourceInfo.fromJson(rawSource);
        final title = widget.season > 0
            ? '${widget.title} - S${widget.season}E${widget.episode}'
            : widget.title;

        if (mounted) {
          Navigator.of(context).pop();
          await PlayerLauncher.playStream(
            context: context,
            title: title,
            source: source,
            player: widget.defaultPlayer,
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _currentStep = PlaybackSelectionStep.error;
            _errorMessage = res['error']?.toString() ??
                'Unable to resolve selected stream quality.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStep = PlaybackSelectionStep.error;
          _errorMessage = 'Stream resolution error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _buildCurrentStep(context),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_currentStep) {
      case PlaybackSelectionStep.audio:
        return _buildAudioStep(context);
      case PlaybackSelectionStep.loadingStreams:
        return _buildLoadingStep('Fetching audio streams & captions...');
      case PlaybackSelectionStep.subtitles:
        return _buildSubtitlesStep(context);
      case PlaybackSelectionStep.quality:
        return _buildQualityStep(context);
      case PlaybackSelectionStep.resolving:
        return _buildLoadingStep('Preparing player & resolving stream...');
      case PlaybackSelectionStep.error:
        return _buildErrorStep(context);
    }
  }

  // -------------------------------------------------------------
  // STEP 1: Audio
  // -------------------------------------------------------------
  Widget _buildAudioStep(BuildContext context) {
    return Column(
      key: const ValueKey('step_audio'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          stepText: 'STEP 1 OF 3',
          title: 'Audio Language',
          subtitle: 'Select audio dubbing for this title',
          canGoBack: false,
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.dubs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final dub = widget.dubs[index];
              final isSelected = _selectedAudio?.subjectId == dub.subjectId;

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _selectedAudio = dub),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.cardBorder,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.audiotrack_rounded,
                        color: isSelected ? AppColors.primaryGlow : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dub.language,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (dub.label != dub.language)
                              Text(
                                dub.label,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      Radio<String>(
                        value: dub.subjectId,
                        groupValue: _selectedAudio?.subjectId,
                        activeColor: AppColors.primary,
                        onChanged: (_) => setState(() => _selectedAudio = dub),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildActionButtons(
          continueLabel: 'Continue',
          onContinue: _fetchStreamsAndSubtitles,
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // STEP 2 & 5: Loading
  // -------------------------------------------------------------
  Widget _buildLoadingStep(String message) {
    return Padding(
      key: ValueKey('loading_$message'),
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 3: Subtitles
  // -------------------------------------------------------------
  Widget _buildSubtitlesStep(BuildContext context) {
    final hasAudioStep = widget.dubs.length > 1;

    return Column(
      key: const ValueKey('step_subtitles'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          stepText: hasAudioStep ? 'STEP 2 OF 3' : 'STEP 1 OF 2',
          title: 'Subtitles',
          subtitle: _availableSubtitles.isEmpty
              ? 'No external subtitles available'
              : 'Choose a caption track or turn off',
          canGoBack: hasAudioStep,
          onBack: () => setState(() => _currentStep = PlaybackSelectionStep.audio),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              // Off Option
              _buildSubtitleCard(
                title: 'Off',
                subtitle: 'Play without external subtitles',
                isSelected: _selectedSubtitle == null,
                onTap: () => setState(() => _selectedSubtitle = null),
              ),
              const SizedBox(height: 8),

              // Subtitle Tracks
              ..._availableSubtitles.map((sub) {
                final isSelected = _selectedSubtitle?.url == sub.url;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildSubtitleCard(
                    title: sub.name,
                    subtitle: 'External SRT subtitle',
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedSubtitle = sub),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildActionButtons(
          continueLabel: 'Continue',
          onContinue: () => setState(() => _currentStep = PlaybackSelectionStep.quality),
        ),
      ],
    );
  }

  Widget _buildSubtitleCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.subtitles_rounded,
              color: isSelected ? AppColors.primaryGlow : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              activeColor: AppColors.primary,
              onChanged: (_) => onTap(),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 4: Quality
  // -------------------------------------------------------------
  Widget _buildQualityStep(BuildContext context) {
    final qualityOptions = _availableQualityOptions;
    if (_selectedQualityOption == null && qualityOptions.isNotEmpty) {
      _selectedQualityOption = qualityOptions.first;
    }

    return Column(
      key: const ValueKey('step_quality'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          stepText: 'FINAL STEP',
          title: 'Video Quality',
          subtitle: 'Select your preferred stream resolution',
          canGoBack: true,
          onBack: () => setState(() => _currentStep = PlaybackSelectionStep.subtitles),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: qualityOptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final opt = qualityOptions[index];
              final isSelected = _selectedQualityOption == opt;
              final qualityLabel = opt.quality.isNotEmpty ? opt.quality : '1080p';

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    _selectedQualityOption = opt;
                    _selectedRelease = opt.release;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.cardBorder,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Quality Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _qualityBadgeColor(qualityLabel),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          qualityLabel.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _qualityDescription(qualityLabel),
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Provider: ${opt.release.provider.toUpperCase()} · DASH Stream',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Radio<QualityOption>(
                        value: opt,
                        groupValue: _selectedQualityOption,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedQualityOption = val;
                              _selectedRelease = val.release;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildActionButtons(
          continueLabel: 'Start Playback',
          continueIcon: Icons.play_arrow,
          onContinue: () {
            if (_selectedQualityOption != null) {
              _selectedRelease = _selectedQualityOption!.release;
            }
            _resolveAndPlay();
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // ERROR STEP
  // -------------------------------------------------------------
  Widget _buildErrorStep(BuildContext context) {
    return Padding(
      key: const ValueKey('step_error'),
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _fetchStreamsAndSubtitles,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------------
  Widget _buildHeader({
    required String stepText,
    required String title,
    required String subtitle,
    required bool canGoBack,
    VoidCallback? onBack,
  }) {
    return Row(
      children: [
        if (canGoBack) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onBack,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stepText,
                style: const TextStyle(
                  color: AppColors.primaryGlow,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildActionButtons({
    required String continueLabel,
    IconData? continueIcon,
    required VoidCallback onContinue,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: continueIcon != null ? Icon(continueIcon, size: 20) : const SizedBox.shrink(),
            label: Text(
              continueLabel,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            onPressed: onContinue,
          ),
        ),
      ],
    );
  }

  Color _qualityBadgeColor(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('4k') || q.contains('uhd') || q.contains('2160')) {
      return AppColors.accentPurple;
    }
    if (q.contains('1080')) {
      return AppColors.accentBlue;
    }
    if (q.contains('720')) {
      return AppColors.accentGreen;
    }
    if (q.contains('480') || q.contains('360')) {
      return AppColors.accentGold;
    }
    return AppColors.primary;
  }

  String _qualityDescription(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('4k') || q.contains('2160')) return 'Ultra HD (4K)';
    if (q.contains('1080')) return 'Full HD (1080p)';
    if (q.contains('720')) return 'High Definition (720p)';
    if (q.contains('480')) return 'Standard Definition (480p)';
    return 'Standard Quality ($quality)';
  }
}
