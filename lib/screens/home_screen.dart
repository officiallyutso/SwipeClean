import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'photo_swipe_screen.dart';
import 'trash_bin_screen.dart';
import 'gallery_screen.dart'; // Import the new gallery screen
import '../services/photo_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PhotoService _photoService = PhotoService();
  int _trashedPhotos = 0;
  double _trashedPhotosSize = 0.0; // in bytes
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _loadStats();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final trashed = await _photoService.getTrashedPhotos();
    
    // Calculate total size of trashed photos only
    final trashedSize = await _photoService.getTotalPhotosSize(trashed);
    
    setState(() {
      _trashedPhotos = trashed.length;
      _trashedPhotosSize = trashedSize;
    });
  }

  String _formatFileSize(double bytes) {
    if (bytes < 1024) {
      return '${bytes.toInt()} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
        border: Border(),
        // Remove the middle title
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // App Title Section
                      _buildAppTitleSection(),
                      SizedBox(height: 24),
                      
                      // Welcome Section
                      _buildWelcomeSection(),
                      SizedBox(height: 32),
                      
                      // Action Buttons
                      _buildActionButton(
                        'Start Cleaning',
                        'Swipe through your photos',
                        CupertinoIcons.photo_on_rectangle,
                        CupertinoColors.systemGreen,
                        () => Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (context) => PhotoSwipeScreen()),
                        ).then((_) => _loadStats()),
                      ),
                      SizedBox(height: 16),

                      _buildActionButton(
                        'Photo Library',
                        'Browse all photos organized by albums',
                        CupertinoIcons.photo_fill_on_rectangle_fill,
                        CupertinoColors.systemBlue,
                        () => Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (context) => GalleryScreen()),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      _buildActionButton(
                        'Trash Bin',
                        'Review deleted photos ($_trashedPhotos items • ${_formatFileSize(_trashedPhotosSize)})',
                        CupertinoIcons.trash,
                        CupertinoColors.systemRed,
                        () => Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (context) => TrashBinScreen()),
                        ).then((_) => _loadStats()),
                      ),
                      SizedBox(height: 40),
                      
                      // How to Use Section
                      _buildHowToUseSection(),
                      SizedBox(height: 20),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitleSection() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                CupertinoColors.systemBlue,
                CupertinoColors.systemPurple,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Center(
  child: Text(
    'SwipeClean',
    style: TextStyle(
      fontSize: 46,
      fontWeight: FontWeight.w900,
      color: CupertinoColors.white,
      decoration: TextDecoration.none,
      letterSpacing: -1.0,
      shadows: [
        Shadow(
          offset: Offset(0.5, 0.5),
          blurRadius: 0.8,
          color: CupertinoColors.white.withOpacity(0.6),
        ),
      ],
    ),
  ),
),

          ),
          SizedBox(height: 4),
          Center(
            child: Text(
              'Swipe left to Clean!',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CupertinoColors.systemBlue.withOpacity(0.1),
            CupertinoColors.systemPurple.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.systemBlue.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.sparkles,
              size: 32,
              color: CupertinoColors.systemBlue,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(
                    'Ready to Clean?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Organize your photos with simple swipes',
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.secondaryLabel,
                      decoration: TextDecoration.none,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.08),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.tertiaryLabel,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowToUseSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.systemBlue.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.info_circle_fill,
                color: CupertinoColors.systemBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'How to Use',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemBlue,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInstructionItem(
            CupertinoIcons.arrow_right_circle,
            'Swipe right to keep photos',
            CupertinoColors.systemGreen,
          ),
          SizedBox(height: 12),
          _buildInstructionItem(
            CupertinoIcons.arrow_left_circle,
            'Swipe left to move to trash',
            CupertinoColors.systemRed,
          ),
          SizedBox(height: 12),
          _buildInstructionItem(
            CupertinoIcons.eye,
            'Review trash before permanent deletion',
            CupertinoColors.systemBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}