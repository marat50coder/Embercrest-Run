import 'package:flutter/material.dart';
import 'web_screen.dart';

import '../core/atlas.dart';
import '../core/audio.dart';
import '../core/palette.dart';
import '../core/save.dart';
import '../game/config.dart';
import '../ui/sprite_image.dart';
import '../ui/widgets.dart';

const privacyPolicyUrl = 'https://embercrestrun.com/privacy-policy.html';
const supportUrl = 'https://embercrestrun.com/support.html';

/// Shared chrome for every menu dialog: title bar, close button, scroll body.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.width = 640});

  final String title;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // `showGeneralDialog` does not inject a Material into the tree, so widgets
    // like Switch crash and Text falls back to the ugly yellow-underline style.
    // Wrapping in a transparent Material fixes both in one place.
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: size.height - 32,
            ),
            child: StonePanel(
              glow: true,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 20, color: Pal.ember),
                      const SizedBox(width: 10),
                      Expanded(child: Text(title, style: Pal.title(19))),
                      Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, color: Pal.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(child: SingleChildScrollView(child: child)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- skins

class SkinsPanel extends StatefulWidget {
  const SkinsPanel({super.key, required this.atlas, required this.save});
  final SpriteAtlas atlas;
  final Save save;

  @override
  State<SkinsPanel> createState() => _SkinsPanelState();
}

class _SkinsPanelState extends State<SkinsPanel> {
  @override
  Widget build(BuildContext context) {
    final save = widget.save;
    return _Panel(
      title: 'HEROES',
      width: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Magma Shards', style: Pal.label(12, color: Pal.muted)),
              const SizedBox(width: 8),
              ResourceChip(
                compact: true,
                color: Pal.crystal,
                amount: save.emberShards,
                image: SpriteImage(
                    atlas: widget.atlas,
                    name: ResourceInfo.map[ResourceKind.shard]!.sprites.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: Skin.all.length,
            itemBuilder: (_, i) => _skinTile(i),
          ),
        ],
      ),
    );
  }

  Widget _skinTile(int i) {
    final skin = Skin.all[i];
    final save = widget.save;
    final unlocked = save.isSkinUnlocked(i);
    final selected = save.selectedSkin == i;
    final affordable = save.emberShards >= skin.price;

    return Pressable(
      onTap: () {
        setState(() {
          if (unlocked) {
            save.selectedSkin = i;
          } else if (save.buySkin(i)) {
            Audio.instance.play(Sfx.victory, volume: 0.7);
          } else {
            Audio.instance.play(Sfx.menuClose, volume: 0.5);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0x66150C0F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Pal.emberBright
                : (unlocked ? const Color(0xFF5A343A) : const Color(0xFF33232A)),
            width: selected ? 2.2 : 1.4,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SpriteImage(
                atlas: widget.atlas,
                name: skin.sprite,
                opacity: unlocked ? 1.0 : 0.32,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              skin.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Pal.label(10, color: unlocked ? Pal.bone : Pal.muted),
            ),
            const SizedBox(height: 3),
            if (selected)
              Text('EQUIPPED', style: Pal.label(9, color: Pal.emberBright))
            else if (unlocked)
              Text('TAP TO WEAR', style: Pal.label(9, color: Pal.muted))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.diamond_rounded,
                      size: 10,
                      color: affordable ? Pal.crystal : Pal.muted),
                  const SizedBox(width: 3),
                  Text('${skin.price}',
                      style: Pal.number(11,
                          color: affordable ? Pal.crystal : Pal.muted)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ quests

class QuestsPanel extends StatelessWidget {
  const QuestsPanel({super.key, required this.save});
  final Save save;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'DAILY QUESTS',
      width: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Resets every day at midnight UTC.',
              style: Pal.label(11, color: Pal.muted, w: FontWeight.w500)),
          const SizedBox(height: 14),
          for (final q in save.quests) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x55150C0F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: q.done ? Pal.emberBright.withValues(alpha: 0.6)
                        : const Color(0xFF44292F)),
              ),
              child: Row(
                children: [
                  Icon(
                    q.done ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: q.done ? Pal.emberBright : Pal.muted,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.label, style: Pal.label(13)),
                        const SizedBox(height: 6),
                        MeterBar(
                          value: q.fraction,
                          color: q.done ? Pal.emberBright : Pal.ember,
                          height: 7,
                        ),
                        const SizedBox(height: 4),
                        Text('${q.progress.clamp(0, q.target)} / ${q.target}',
                            style: Pal.label(10, color: Pal.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      const Icon(Icons.diamond_rounded,
                          size: 14, color: Pal.crystal),
                      Text('${q.reward}', style: Pal.number(13, color: Pal.crystal)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- collection

class CollectionPanel extends StatelessWidget {
  const CollectionPanel({super.key, required this.atlas, required this.save});
  final SpriteAtlas atlas;
  final Save save;

  @override
  Widget build(BuildContext context) {
    final found = save.artifacts;
    final magma = save.magmaFound;
    return _Panel(
      title: 'COLLECTION',
      width: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('MAGMA TYPES  ${magma.length}/${MagmaType.values.length}'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final t in MagmaType.values) ...[
                Expanded(child: _magmaTile(t, magma.contains(t.index))),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _sectionTitle('ARTIFACTS  ${found.length}/${Artifacts.all.length}'),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 9,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: Artifacts.all.length,
            itemBuilder: (_, i) {
              final has = found.contains(i);
              return Tooltip(
                message: has ? Artifacts.names[i] : 'Undiscovered',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0x55150C0F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: has ? const Color(0xFF6A3B33) : const Color(0xFF2C1E23)),
                  ),
                  child: SpriteImage(
                    atlas: atlas,
                    name: Artifacts.all[i],
                    opacity: has ? 1 : 0.18,
                    tint: has ? null : Colors.black,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: Pal.label(12, color: Pal.emberBright));

  Widget _magmaTile(MagmaType type, bool found) {
    final info = MagmaInfo.of(type);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x55150C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: found ? info.color.withValues(alpha: 0.55)
                : const Color(0xFF2C1E23)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: SpriteImage(
                atlas: atlas, name: info.orbSprite, opacity: found ? 1 : 0.2),
          ),
          const SizedBox(height: 4),
          Text(
            found ? info.label.split(' ').first.toUpperCase() : '???',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Pal.label(9, color: found ? info.color : Pal.muted),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- help

class HowToPanel extends StatelessWidget {
  const HowToPanel({super.key, required this.atlas});
  final SpriteAtlas atlas;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'HOW TO RUN',
      width: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rule(Icons.touch_app_rounded, 'Hold to steer',
              'Press anywhere and slide left or right. The further from the '
              'centre you hold, the harder the crest turns. Flick for a sharp turn.'),
          _rule(Icons.local_fire_department_rounded, 'The crest is temporary',
              'Fresh magma is bright, then it cools, cracks and falls away. '
              'Crossing your own cracked path ends the run.'),
          _rule(Icons.bolt_rounded, 'Magma energy is your fuel',
              'Building road burns energy. Collect crystals and ores to refill '
              'it — run dry and the crest stops growing.'),
          _rule(Icons.compress_rounded, 'Pressure builds in straight lines',
              'Hold one heading too long and the volcano erupts ahead of you. '
              'Winding routes keep the pressure down.'),
          _rule(Icons.ac_unit_rounded, 'Crystallise to cross safely',
              'The freeze button hardens the crest behind you. Hardened road '
              'never decays, so you can cross it again.'),
          _rule(Icons.blur_circular_rounded, 'Ancient cores change everything',
              'Driving over a core grants a magma type: magnetic, crystalline, '
              'obsidian, explosive or living.'),
        ],
      ),
    );
  }

  Widget _rule(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0x55150C0F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Pal.emberBright),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Pal.label(13)),
                const SizedBox(height: 3),
                Text(body,
                    style: Pal.label(11.5, color: Pal.muted, w: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- settings

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.save});
  final Save save;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  void _openInApp(BuildContext ctx, String title, String url) {
    // Push the WebScreen on top of the dialog stack.
    Navigator.of(ctx).push(MaterialPageRoute<void>(
      builder: (_) => WebScreen(title: title, url: url),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final save = widget.save;
    return _Panel(
      title: 'SETTINGS',
      width: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toggle('Music', save.musicOn, (v) {
            save.setSetting('music', v);
            Audio.instance.setMusicEnabled(v);
            setState(() {});
          }),
          _toggle('Sound effects', save.sfxOn, (v) {
            save.setSetting('sfx', v);
            Audio.instance.setSfxEnabled(v);
            setState(() {});
          }),
          _toggle('Screen shake', save.shakeOn, (v) {
            save.setSetting('shake', v);
            setState(() {});
          }),
          _toggle('Left-handed controls', save.leftHanded, (v) {
            save.setSetting('leftHanded', v);
            setState(() {});
          }),
          const SizedBox(height: 20),
          Text('ABOUT', style: Pal.label(12, color: Pal.emberBright)),
          const SizedBox(height: 10),
          _webButton(
            context,
            icon: Icons.privacy_tip_rounded,
            label: 'Privacy Policy',
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1B60), Color(0xFF3D28A0)],
            ),
            onTap: () => _openInApp(context, 'Privacy Policy', privacyPolicyUrl),
          ),
          const SizedBox(height: 10),
          _webButton(
            context,
            icon: Icons.support_agent_rounded,
            label: 'Support',
            gradient: const LinearGradient(
              colors: [Color(0xFF1A3A28), Color(0xFF1F6040)],
            ),
            onTap: () => _openInApp(context, 'Support', supportUrl),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('Embercrest Run  •  v1.0.0',
                style: Pal.label(10, color: Pal.muted, w: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Pal.label(13))),
          Switch(
            value: value,
            activeThumbColor: Pal.emberBright,
            activeTrackColor: Pal.emberDeep,
            inactiveTrackColor: const Color(0xFF2A1B20),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _webButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.last.withValues(alpha: 0.40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
