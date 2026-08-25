import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../database/services/chat_service.dart';
import '../chat/chat_window_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../database/services/flare_service.dart';
import '../../../database/services/firestore_service.dart';
import '../../../database/services/pet_search_service.dart';
import '../../widgets/app_background.dart';
import 'pet_match_models.dart';
import 'pet_match_widgets.dart';

class PetMatchDetailsScreen extends StatefulWidget {
  const PetMatchDetailsScreen(
      {super.key,
      required this.searchImage,
      required this.match,
      this.onChat,
      this.onCall,
      this.onViewContact});
  final File searchImage;
  final PetMatchResult match;
  final VoidCallback? onChat, onCall, onViewContact;

  @override
  State<PetMatchDetailsScreen> createState() => _PetMatchDetailsScreenState();
}

class _PetMatchDetailsScreenState extends State<PetMatchDetailsScreen> {
  late final Future<PetMatchResult> _authoritativeMatch = _loadMatch();

  Future<PetMatchResult> _loadMatch() async {
    final flare = await FlareService().getFlare(widget.match.flareId);
    if (flare == null) throw StateError('This Flare is no longer available.');
    final uploader = await FirestoreService().getUserProfile(flare.authorUid);
    final hit = Pet(
      id: widget.match.id,
      flareId: widget.match.flareId,
      ownerId: widget.match.ownerId,
      species: widget.match.pet.species,
      imageUrl: widget.match.imageUrl,
      score: widget.match.similarity,
    );
    return PetMatchResult.fromPet(hit, flare: flare, user: uploader);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PetMatchResult>(
        future: _authoritativeMatch,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Match Details')),
              body: Center(
                  child: Text('Could not load match: ${snapshot.error}')),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return _PetMatchDetailsView(
            searchImage: widget.searchImage,
            match: snapshot.data!,
            onChat: widget.onChat,
            onCall: widget.onCall,
            onViewContact: widget.onViewContact,
          );
        },
      );
}

class _PetMatchDetailsView extends StatelessWidget {
  const _PetMatchDetailsView(
      {required this.searchImage,
      required this.match,
      this.onChat,
      this.onCall,
      this.onViewContact});
  final File searchImage;
  final PetMatchResult match;
  final VoidCallback? onChat, onCall, onViewContact;

  Future<void> _callUploader(BuildContext context) async {
    final phone = match.uploader.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('The uploader has not shared a phone number.')),
      );
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone app.')),
      );
    }
  }

  void _showContact(BuildContext context) {
    final uploader = match.uploader;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
              title: Text(uploader.name),
              subtitle: const Text('Uploader contact')),
          if (uploader.phone != null)
            ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: Text(uploader.phone!)),
          if (uploader.email != null)
            ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(uploader.email!)),
          if (uploader.location != null)
            ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(uploader.location!)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return AppBackground(
        showWatermark: false,
        child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('Match Details'), actions: [
              IconButton(
                  onPressed: () {}, icon: const Icon(Icons.share_outlined))
            ]),
            body: SafeArea(
                top: false,
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _ImageComparison(searchImage: searchImage, match: match),
                      const SizedBox(height: 13),
                      _InfoCard(
                          title: 'Pet Details',
                          icon: Icons.pets_rounded,
                          children: [
                            _InfoRow(
                                icon: Icons.badge_outlined,
                                label: 'Name',
                                value: match.pet.name),
                            _InfoRow(
                                icon: Icons.category_outlined,
                                label: 'Species',
                                value: match.pet.species),
                            _InfoRow(
                                icon: Icons.cruelty_free_outlined,
                                label: 'Breed',
                                value: match.pet.breed),
                            _InfoRow(
                                icon: Icons.location_on_outlined,
                                label: 'Location',
                                value: match.pet.location),
                            if (match.pet.color != null)
                              _InfoRow(
                                  icon: Icons.palette_outlined,
                                  label: 'Color',
                                  value: match.pet.color!),
                            if (match.pet.gender != null)
                              _InfoRow(
                                  icon: Icons.male_outlined,
                                  label: 'Gender',
                                  value: match.pet.gender!),
                            if (match.pet.age != null)
                              _InfoRow(
                                  icon: Icons.timer_outlined,
                                  label: 'Age',
                                  value: match.pet.age!),
                            if (match.pet.lastSeen != null)
                              _InfoRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Last Seen',
                                  value: match.pet.lastSeen!),
                            if (match.pet.note != null)
                              _InfoRow(
                                  icon: Icons.chat_bubble_outline,
                                  label: 'Status / Note',
                                  value: match.pet.note!),
                          ]),
                      const SizedBox(height: 10),
                      _UploaderCard(uploader: match.uploader),
                      const SizedBox(height: 11),
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                              onPressed: onChat ??
                                  () async {
                                    try {
                                      final id = await ChatService()
                                          .openOrCreateDirectConversation(
                                              match.ownerId,
                                              contextFlareId: match.flareId);
                                      if (context.mounted) {
                                        Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    ChatWindowScreen(
                                                        conversationId: id,
                                                        otherUid: match.ownerId,
                                                        contactName:
                                                            match.uploader.name,
                                                        avatarUrl: match
                                                            .uploader.avatarUrl,
                                                        contextFlareId:
                                                            match.flareId)));
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text('$error')));
                                      }
                                    }
                                  },
                              icon: const Icon(Icons.forum_rounded),
                              label: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Chat Now',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17)),
                                    Text('Direct Chat in App',
                                        style: TextStyle(fontSize: 10))
                                  ]))),
                      const SizedBox(height: 9),
                      Row(children: [
                        Expanded(
                            child: _OutlineAction(
                                icon: Icons.call_rounded,
                                label: 'Call',
                                onTap: onCall ?? () => _callUploader(context))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _OutlineAction(
                                icon: Icons.person_rounded,
                                label: 'View Contact',
                                onTap: onViewContact ??
                                    () => _showContact(context)))
                      ]),
                      const SizedBox(height: 18),
                      Center(
                          child: Text(
                              'Your safety is our priority. Please chat within the app.',
                              style: TextStyle(
                                  color: ext.textSecondary, fontSize: 10))),
                    ]))));
  }
}

class _ImageComparison extends StatelessWidget {
  const _ImageComparison({required this.searchImage, required this.match});
  final File searchImage;
  final PetMatchResult match;
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return SizedBox(
        height: 264,
        child: Stack(clipBehavior: Clip.none, children: [
          Row(children: [
            Expanded(
                child: _LabeledImage(
                    label: 'Matched database image',
                    child: MatchImage(
                        imageUrl: match.imageUrl, fit: BoxFit.cover))),
            const SizedBox(width: 12),
            Expanded(
                child: _LabeledImage(
                    label: 'Your search image',
                    child: MatchImage(file: searchImage, fit: BoxFit.cover)))
          ]),
          Align(
              alignment: Alignment.center,
              child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF082529),
                      border: Border.all(color: ext.accentOrange, width: 2),
                      boxShadow: [
                        BoxShadow(color: ext.accentOrangeGlow, blurRadius: 18)
                      ]),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${match.similarityPercent}%',
                            style: TextStyle(
                                color: ext.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 24)),
                        Text('Match',
                            style: TextStyle(
                                color: ext.textSecondary, fontSize: 11))
                      ])))
        ]));
  }
}

class _LabeledImage extends StatelessWidget {
  const _LabeledImage({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(children: [
          Positioned.fill(child: child),
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  color: ext.cardBackground.withValues(alpha: .88),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ext.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600))))
        ]));
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: ext.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ext.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: ext.accentOrange),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                    color: ext.textPrimary, fontWeight: FontWeight.w700))
          ]),
          const SizedBox(height: 13),
          Wrap(runSpacing: 15, children: children)
        ]));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return SizedBox(
        width: MediaQuery.sizeOf(context).width > 430 ? 190 : 150,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFFAFC5D8), size: 21),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(color: ext.textSecondary, fontSize: 10)),
                Text(value,
                    style: TextStyle(color: ext.textPrimary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)
              ]))
        ]));
  }
}

class _UploaderCard extends StatelessWidget {
  const _UploaderCard({required this.uploader});
  final PetMatchUploader uploader;
  @override
  Widget build(BuildContext context) {
    return _InfoCard(
        title: 'Uploader Contact',
        icon: Icons.person_rounded,
        children: [
          Row(children: [
            CircleAvatar(
                radius: 29,
                backgroundColor: const Color(0xFF1D3038),
                backgroundImage: uploader.avatarUrl == null
                    ? null
                    : NetworkImage(uploader.avatarUrl!),
                child: uploader.avatarUrl == null
                    ? const Icon(Icons.person, color: Color(0xFFAFC5D8))
                    : null),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(uploader.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (uploader.phone != null)
                    Text(uploader.phone!, style: const TextStyle(fontSize: 12)),
                  if (uploader.email != null)
                    Text(uploader.email!, style: const TextStyle(fontSize: 11))
                ])),
            if (uploader.isVerified)
              const Icon(Icons.verified_user_outlined, color: Color(0xFF08B8BC))
          ])
        ]);
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ResQThemeExtension>()!;
    return OutlinedButton.icon(
        onPressed: onTap ?? () {},
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
            foregroundColor: ext.accentOrange,
            side: BorderSide(color: ext.outlinedButtonBorder),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))));
  }
}
