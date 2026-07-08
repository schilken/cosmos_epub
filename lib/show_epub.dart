import 'dart:convert';
import 'dart:developer';
import 'dart:io' show File, Platform;

import 'package:cosmos_epub/Component/notes_list_screen.dart';
import 'package:cosmos_epub/Helpers/context_extensions.dart';
import 'package:cosmos_epub/Helpers/epub_content_parser.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/Helpers/note_exporter.dart';
import 'package:cosmos_epub/Helpers/search_bottom_sheet.dart';
import 'package:cosmos_epub/Helpers/search_service.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:cosmos_epub/Model/search_controller.dart';
import 'package:cosmos_epub/Model/search_result.dart';
import 'package:epubx/epubx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:html/parser.dart' as html_parser;

import 'Component/constants.dart';
import 'Component/circle_button.dart';
import 'Component/theme_colors.dart';
import 'Helpers/chapters.dart';
import 'Helpers/custom_toast.dart';
import 'Helpers/drift_progress_service.dart';
import 'Helpers/pagination.dart';
import 'Model/chapter_model.dart';

late DriftProgressService bookProgress;

const double DESIGN_WIDTH = 375;
const double DESIGN_HEIGHT = 812;

String selectedFont = 'Segoe';
List<String> fontNames = [
  "Segoe",
  "Alegreya",
  "Amazon Ember",
  "Atkinson Hyperlegible",
  "Bitter Pro",
  "Bookerly",
  "Droid Sans",
  "EB Garamond",
  "Gentium Book Plus",
  "Halant",
  "IBM Plex Sans",
  "LinLibertine",
  "Literata",
  "Lora",
  "Ubuntu"
];

Color backColor = Colors.white;
Color fontColor = Colors.black;
int staticThemeId = 3;

// ignore: must_be_immutable
class ShowEpub extends StatefulWidget {
  EpubBook epubBook;
  bool shouldOpenDrawer;
  int starterChapter;
  final String bookId;
  final String chapterListTitle;
  final Function(int currentPage, int totalPages)? onPageFlip;
  final Function(int lastPageIndex)? onLastPage;
  final Color accentColor;
  final VoidCallback? onBack;

  ShowEpub({
    super.key,
    required this.epubBook,
    required this.accentColor,
    this.starterChapter = 0,
    this.shouldOpenDrawer = false,
    required this.bookId,
    required this.chapterListTitle,
    this.onPageFlip,
    this.onLastPage,
    this.onBack,
  });

  @override
  State<StatefulWidget> createState() => ShowEpubState();
}

class ShowEpubState extends State<ShowEpub> {
  String htmlContent = '';
  EpubContentParser? contentParser;
  bool showBrightnessWidget = false;
  final controller = ScrollController();
  Future<void> loadChapterFuture = Future.value(true);
  List<LocalChapterModel> chaptersList = [];
  double _fontSizeProgress = 17.0;
  double _fontSize = 17.0;
  TextDirection currentTextDirection = TextDirection.ltr;

  late EpubBook epubBook;
  late String bookId;
  String bookTitle = '';
  String chapterTitle = '';
  double brightnessLevel = 0.5;

  late String selectedTextStyle;

  bool showHeader = true;
  bool showPrevious = false;
  bool showNext = false;
  int _currentChapterIndex = 0;
  int _currentPageIndex = 0;
  int? _pendingJumpPageIndex;
  var dropDownFontItems;

  GetStorage gs = GetStorage();

  PagingTextHandler controllerPaging = PagingTextHandler(paginate: () {});

  final EpubSearchController _searchController = EpubSearchController();
  bool _isSearchSheetOpen = false;

  @override
  void initState() {
    loadThemeSettings();

    bookId = widget.bookId;
    epubBook = widget.epubBook;
    selectedTextStyle =
        fontNames.where((element) => element == selectedFont).first;

    getTitleFromXhtml();
    reLoadChapter(init: true);

    _restoreSearchState();

    super.initState();
  }

  void _restoreSearchState() {
    final gs = GetStorage();
    final key = '$libSearchPrefix$bookId';
    if (gs.read<String>(key) != null) {
      _searchController.loadFromStorage(bookId);
    }
  }

  loadThemeSettings() {
    selectedFont = gs.read(libFont) ?? selectedFont;
    var themeId = gs.read(libTheme) ?? staticThemeId;
    updateTheme(themeId, isInit: true);
    _fontSize = gs.read(libFontSize) ?? _fontSize;
    _fontSizeProgress = _fontSize;
  }

  getTitleFromXhtml() {
    if (epubBook.Title != null) {
      bookTitle = epubBook.Title!;
      updateUI();
    }
  }

  reLoadChapter({bool init = false, int index = -1}) async {
    final progress = await bookProgress.getBookProgress(bookId);
    int currentIndex = progress.currentChapterIndex ?? 0;

    setState(() {
      loadChapterFuture = loadChapter(
          index: init
              ? -1
              : index == -1
                  ? currentIndex
                  : index);
    });
  }

  loadChapter({int index = -1}) async {
    // Build content parser once — it extracts chapters and images
    contentParser ??= EpubContentParser(epubBook);
    chaptersList = contentParser!.flatChapters;

    if (widget.starterChapter >= 0 &&
        widget.starterChapter < chaptersList.length) {
      setupNavButtons();
      await updateContentAccordingChapter(
          index == -1 ? widget.starterChapter : index);
    } else {
      setupNavButtons();
      await updateContentAccordingChapter(0);
      CustomToast.showToast(
          "Invalid chapter number. Range [0-${chaptersList.length}]");
    }
  }

  updateContentAccordingChapter(int chapterIndex) async {
    await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
    _currentChapterIndex = chapterIndex;

    if (chapterIndex >= 0 && chapterIndex < chaptersList.length) {
      htmlContent = chaptersList[chapterIndex].htmlContent;
    }

    // Extract plain text for direction detection
    final textContent =
        html_parser.parse(htmlContent).documentElement?.text ?? '';
    currentTextDirection = RTLHelper.getTextDirection(textContent);

    controllerPaging.paginate();
    setupNavButtons();
  }

  setupNavButtons() async {
    final progress = await bookProgress.getBookProgress(bookId);
    int index = progress.currentChapterIndex ?? 0;
    _currentChapterIndex = index;
    _currentPageIndex = progress.currentPageIndex ?? 0;

    setState(() {
      if (index == 0) {
        showPrevious = false;
      } else {
        showPrevious = true;
      }
      if (index == chaptersList.length - 1) {
        showNext = false;
      } else {
        showNext = true;
      }
    });
  }

  Future<bool> backPress() async {
    return true;
  }

  void setBrightness(double brightness) async {
    if (!Platform.isMacOS) {
      // screen_brightness is not supported on macOS
      await Future.delayed(const Duration(seconds: 5));
      showBrightnessWidget = false;
      updateUI();
    }
  }

  Widget _buildFontSettingsContent(StateSetter setState) {
    return SingleChildScrollView(
        child: StatefulBuilder(
            builder: (BuildContext context, setState) => SizedBox(
                  height: 170.h,
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.symmetric(
                            horizontal: 10.h, vertical: 8.w),
                        height: 45.h,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                updateTheme(1);
                              },
                              child: CircleButton(
                                backColor: cVioletishColor,
                                fontColor: Colors.black,
                                id: 1,
                                accentColor: widget.accentColor,
                              ),
                            ),
                            SizedBox(
                              width: 10.w,
                            ),
                            GestureDetector(
                              onTap: () {
                                updateTheme(2);
                              },
                              child: CircleButton(
                                backColor: cBluishColor,
                                fontColor: Colors.black,
                                id: 2,
                                accentColor: widget.accentColor,
                              ),
                            ),
                            SizedBox(
                              width: 10.w,
                            ),
                            GestureDetector(
                              onTap: () {
                                updateTheme(3);
                              },
                              child: CircleButton(
                                id: 3,
                                backColor: Colors.white,
                                fontColor: Colors.black,
                                accentColor: widget.accentColor,
                              ),
                            ),
                            SizedBox(
                              width: 10.w,
                            ),
                            GestureDetector(
                              onTap: () {
                                updateTheme(4);
                              },
                              child: CircleButton(
                                id: 4,
                                backColor: Colors.black,
                                fontColor: Colors.white,
                                accentColor: widget.accentColor,
                              ),
                            ),
                            SizedBox(
                              width: 10.w,
                            ),
                            GestureDetector(
                              onTap: () {
                                updateTheme(5);
                              },
                              child: CircleButton(
                                id: 5,
                                backColor: cPinkishColor,
                                fontColor: Colors.black,
                                accentColor: widget.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        thickness: 1.h,
                        height: 0,
                        indent: 0,
                        color: Colors.grey,
                      ),
                      Expanded(
                        child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20.h),
                            child: Column(
                              children: [
                                StatefulBuilder(
                                  builder: (BuildContext context,
                                          StateSetter setState) =>
                                      Theme(
                                    data: Theme.of(context)
                                        .copyWith(canvasColor: backColor),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                          value: selectedFont,
                                          isExpanded: true,
                                          menuMaxHeight: 400.h,
                                          onChanged: (newValue) {
                                            selectedFont = newValue ?? 'Segoe';

                                            selectedTextStyle = fontNames
                                                .where((element) =>
                                                    element == selectedFont)
                                                .first;

                                            gs.write(libFont, selectedFont);

                                            setState(() {});
                                            controllerPaging.paginate();
                                            updateUI();
                                          },
                                          items: fontNames
                                              .map<DropdownMenuItem<String>>(
                                                  (String font) {
                                            return DropdownMenuItem<String>(
                                              value: font,
                                              child: Text(
                                                font,
                                                style: TextStyle(
                                                    color: selectedFont == font
                                                        ? widget.accentColor
                                                        : fontColor,
                                                    package: 'cosmos_epub',
                                                    fontSize: context.isTablet
                                                        ? 24.sp
                                                        : 24.sp,
                                                    fontWeight:
                                                        selectedFont == font
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                    fontFamily: font),
                                              ),
                                            );
                                          }).toList()),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "Aa",
                                      style: TextStyle(
                                          fontSize: 15.sp,
                                          color: fontColor,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        activeColor: staticThemeId == 4
                                            ? Colors.grey.withOpacity(0.8)
                                            : Colors.blue,
                                        value: _fontSizeProgress,
                                        min: 15.0,
                                        max: 30.0,
                                        onChangeEnd: (double value) {
                                          _fontSize = value;

                                          gs.write(libFontSize, _fontSize);

                                          updateUI();
                                          controllerPaging.paginate();
                                        },
                                        onChanged: (double value) {
                                          setState(() {
                                            _fontSizeProgress = value;
                                          });
                                        },
                                      ),
                                    ),
                                    Text(
                                      "Aa",
                                      style: TextStyle(
                                          color: fontColor,
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                )
                              ],
                            )),
                      ),
                    ],
                  ),
                )));
  }

  updateFontSettings() {
    if (Platform.isMacOS) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          backgroundColor: backColor,
          child: _buildFontSettingsContent(setState),
        ),
      );
    }
    return showModalBottomSheet(
        context: context,
        elevation: 10,
        clipBehavior: Clip.antiAlias,
        backgroundColor: backColor,
        enableDrag: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r))),
        builder: (context) {
          return _buildFontSettingsContent(setState);
        });
  }

  updateTheme(int id, {bool isInit = false}) {
    staticThemeId = id;
    if (id == 1) {
      backColor = cVioletishColor;
      fontColor = Colors.black;
    } else if (id == 2) {
      backColor = cBluishColor;
      fontColor = Colors.black;
    } else if (id == 3) {
      backColor = Colors.white;
      fontColor = Colors.black;
    } else if (id == 4) {
      backColor = Colors.black;
      fontColor = Colors.white;
    } else {
      backColor = cPinkishColor;
      fontColor = Colors.black;
    }

    gs.write(libTheme, id);

    if (!isInit) {
      Navigator.of(context).pop();
      controllerPaging.paginate();
      updateUI();
    }
  }

  updateUI() {
    setState(() {});
  }

  nextChapter() async {
    await bookProgress.setCurrentPageIndex(bookId, 0);

    _clearSearchState();

    final progress = await bookProgress.getBookProgress(bookId);
    var index = progress.currentChapterIndex ?? 0;

    if (index != chaptersList.length - 1) {
      reLoadChapter(index: index + 1);
    }
  }

  prevChapter() async {
    await bookProgress.setCurrentPageIndex(bookId, 0);

    _clearSearchState();

    final progress = await bookProgress.getBookProgress(bookId);
    var index = progress.currentChapterIndex ?? 0;

    if (index != 0) {
      reLoadChapter(index: index - 1);
    }
  }

  void _onSearchSheetClosed() {
    _clearSearchState();
    setState(() {});
  }

  void _clearSearchState() {
    _searchController.clear();
    _searchController.clearStorage(bookId);
  }

  void _openSearchSheet() {
    _searchController.setChapters(chaptersList);
    _searchController.loadFromStorage(bookId);
    _isSearchSheetOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: backColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: SearchBottomSheet(
            chapters: chaptersList,
            searchController: _searchController,
            accentColor: widget.accentColor,
            backgroundColor: backColor,
            fontColor: fontColor,
            onResultTapped: _onSearchResultTapped,
            onClose: _onSearchSheetClosed,
          ),
        );
      },
    ).then((_) {
      _isSearchSheetOpen = false;
      if (_searchController.isActive && _searchController.results.isNotEmpty) {
        updateUI();
      }
    });
  }

  void _onSearchResultTapped(SearchResult result) {
    _searchController.isActive = true;
    _searchController.saveToStorage(bookId);

    final chapterIndex = result.chapterIndex;

    if (chapterIndex == _currentChapterIndex) {
      final fragments = controllerPaging.pageHtmlFragments;
      final pageIndex = findPageContainingMatch(
          fragments, result.matchStart, result.matchEnd);
      final effectivePage = pageIndex == -1 ? 0 : pageIndex;
      jumpToChapter(chapterIndex, effectivePage);
    } else {
      jumpToChapter(chapterIndex, 0);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final fragments = controllerPaging.pageHtmlFragments;
          final pageIndex = findPageContainingMatch(
              fragments, result.matchStart, result.matchEnd);
          final effectivePage = pageIndex == -1 ? 0 : pageIndex;
          jumpToChapter(chapterIndex, effectivePage);
        });
      });
    }
  }

  int _findPageForNote(List<String> pageHtmlFragments, HighlightModel note) {
    log('_findPageForNote: selectedText="${note.selectedText}" paragraphKey=${note.paragraphKey} startIndex=${note.startIndex}');
    for (var i = 0; i < pageHtmlFragments.length; i++) {
      try {
        final doc = html_parser.parse(pageHtmlFragments[i]);
        final body = doc.body ?? doc.documentElement;
        if (body == null) {
          log('  page $i: body is null');
          continue;
        }

        final toRemove =
            body.querySelectorAll('script, style, head, meta, link, title');
        for (final el in toRemove) {
          el.remove();
        }

        final pageText = body.text;
        final pageKey = HighlightModel.makeParagraphKey(pageText);
        if (pageKey == note.paragraphKey) {
          log('  page $i: FOUND by pageKey ($pageKey), returning $i');
          return i;
        }

        final found = pageText.contains(note.selectedText);
        log('  page $i: pageKey=$pageKey textLen=${pageText.length} selectedFound=$found');
        if (found) {
          log('  → returning page $i (selectedText fallback)');
          return i;
        }
      } catch (e) {
        log('  page $i: parse error: $e');
        continue;
      }
    }
    log('  → NOT FOUND, fallback to 0');
    return 0;
  }

  void _navigateToNotePage(HighlightModel note, int chapterIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fragments = controllerPaging.pageHtmlFragments;
      if (fragments.isEmpty) {
        log('  fragments still empty, polling again...');
        _navigateToNotePage(note, chapterIndex);
        return;
      }
      log('  fragments ready, count: ${fragments.length}');
      final pageIndex = _findPageForNote(fragments, note);
      log('  _findPageForNote returned pageIndex=$pageIndex');
      jumpToChapter(chapterIndex, pageIndex);
    });
  }

  void _onNoteTapped(HighlightModel note) {
    final chapterIndex = note.chapterIndex;
    log('_onNoteTapped: noteChapter=$chapterIndex currentChapter=$_currentChapterIndex sameChapter=${chapterIndex == _currentChapterIndex}');

    if (chapterIndex == _currentChapterIndex) {
      final fragments = controllerPaging.pageHtmlFragments;
      log('  same-chapter, fragments count: ${fragments.length}');
      final pageIndex = _findPageForNote(fragments, note);
      log('  _findPageForNote returned pageIndex=$pageIndex');
      jumpToChapter(chapterIndex, pageIndex);
    } else {
      log('  cross-chapter, jumping to chapter $chapterIndex page 0 first');
      jumpToChapter(chapterIndex, 0);
      _navigateToNotePage(note, chapterIndex);
    }
  }

  void jumpToChapter(int chapterIndex, int pageIndex) {
    final maxChapter = chaptersList.isEmpty ? 0 : chaptersList.length - 1;
    final effectiveChapterIdx = chapterIndex.clamp(0, maxChapter);
    final effectivePageIdx = pageIndex < 0 ? 0 : pageIndex;

    bookProgress.setCurrentChapterIndex(bookId, effectiveChapterIdx);
    bookProgress.setCurrentPageIndex(bookId, effectivePageIdx);
    _currentPageIndex = effectivePageIdx;

    if (effectiveChapterIdx == _currentChapterIndex) {
      log('jumpToChapter: same-chapter pendingJumpPageIndex=$effectivePageIdx (was $_pendingJumpPageIndex)');
      _pendingJumpPageIndex = effectivePageIdx;
      updateUI();
    } else {
      reLoadChapter(index: effectiveChapterIdx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingJumpPageIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(
      context,
      designSize: Platform.isMacOS
          ? const Size(1280, 800)
          : const Size(DESIGN_WIDTH, DESIGN_HEIGHT),
      minTextAdapt: true,
      splitScreenMode: !Platform.isMacOS,
    );

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) backPress();
        },
        child: Theme(
            data: Theme.of(context).copyWith(
              textSelectionTheme: const TextSelectionThemeData(
                selectionColor: Color(0x664285F4),
                selectionHandleColor: Color(0xFF4285F4),
              ),
            ),
            child: Scaffold(
              backgroundColor: backColor,
              body: SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                            child: Stack(
                          children: [
                            FutureBuilder<void>(
                                future: loadChapterFuture,
                                builder: (context, snapshot) {
                                  switch (snapshot.connectionState) {
                                    case ConnectionState.waiting:
                                      {
                                        return Center(
                                            child: CupertinoActivityIndicator(
                                          color: Theme.of(context).primaryColor,
                                          radius: 30.r,
                                        ));
                                      }
                                    default:
                                      {
                                        if (widget.shouldOpenDrawer) {
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                            openTableOfContents();
                                          });

                                          widget.shouldOpenDrawer = false;
                                        }

                                        var currentChapterIndex =
                                            _currentChapterIndex;

                                        return PagingWidget(
                                          htmlContent: htmlContent,
                                          contentParser: contentParser,
                                          bookId: bookId,
                                          chapterIndex: currentChapterIndex,
                                          rawFontFamily: selectedTextStyle,
                                          accentColor: widget.accentColor,
                                          backgroundColor: backColor,
                                          lastWidget: null,
                                          starterPageIndex: _currentPageIndex,
                                          pendingJumpPageIndex:
                                              _pendingJumpPageIndex,
                                          searchQuery:
                                              _searchController.isActive
                                                  ? _searchController.query
                                                  : null,
                                          anchorFragment:
                                              chaptersList[currentChapterIndex]
                                                  .anchorFragment,
                                          style: TextStyle(
                                              fontSize: _fontSize.sp,
                                              fontFamily: selectedTextStyle,
                                              package: 'cosmos_epub',
                                              color: fontColor),
                                          handlerCallback: (ctrl) {
                                            controllerPaging = ctrl;
                                          },
                                          onTextTap: () {
                                            if (showHeader) {
                                              showHeader = false;
                                            } else {
                                              showHeader = true;
                                            }
                                            updateUI();
                                          },
                                          onPageFlip:
                                              (currentPage, totalPages) {
                                            widget.onPageFlip
                                                ?.call(currentPage, totalPages);

                                            bookProgress.setCurrentPageIndex(
                                                bookId, currentPage);

                                            updateUI();
                                          },
                                          onLastPage:
                                              (index, totalPages) async {
                                            widget.onLastPage?.call(index);
                                            nextChapter();
                                          },
                                          onFirstPageBack: (index, totalPages) {
                                            prevChapter();
                                          },
                                          chapterTitle:
                                              chaptersList[currentChapterIndex]
                                                  .chapter,
                                          totalChapters: chaptersList.length,
                                        );
                                      }
                                  }
                                }),
                            if (!Platform.isMacOS)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Visibility(
                                  visible: showBrightnessWidget,
                                  child: Container(
                                      height: 150.h,
                                      width: 30.w,
                                      alignment: Alignment.bottomCenter,
                                      margin: EdgeInsets.only(
                                          bottom: 40.h, right: 15.w),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.brightness_7,
                                            size: 14.h,
                                            color: fontColor,
                                          ),
                                          SizedBox(
                                            height: 120.h,
                                            width: 30.w,
                                            child: RotatedBox(
                                                quarterTurns: -1,
                                                child: SliderTheme(
                                                    data: SliderThemeData(
                                                      activeTrackColor:
                                                          staticThemeId == 4
                                                              ? Colors.white
                                                              : Colors.blue,
                                                      disabledThumbColor:
                                                          Colors.transparent,
                                                      inactiveTrackColor: Colors
                                                          .grey
                                                          .withOpacity(0.5),
                                                      trackHeight: 5.0,
                                                      thumbColor:
                                                          staticThemeId == 4
                                                              ? Colors.grey
                                                                  .withOpacity(
                                                                      0.8)
                                                              : Colors.blue,
                                                      thumbShape:
                                                          RoundSliderThumbShape(
                                                              enabledThumbRadius:
                                                                  0.r),
                                                      overlayShape:
                                                          RoundSliderOverlayShape(
                                                              overlayRadius:
                                                                  10.r),
                                                    ),
                                                    child: Slider(
                                                      value: brightnessLevel,
                                                      min: 0.0,
                                                      max: 1.0,
                                                      onChangeEnd:
                                                          (double value) {
                                                        setBrightness(value);
                                                      },
                                                      onChanged:
                                                          (double value) {
                                                        setState(() {
                                                          brightnessLevel =
                                                              value;
                                                        });
                                                      },
                                                    ))),
                                          ),
                                        ],
                                      )),
                                ),
                              )
                          ],
                        )),
                        AnimatedContainer(
                          height: showHeader ? 40.h : 0,
                          duration: const Duration(milliseconds: 100),
                          color: backColor,
                          child: Container(
                            height: 40.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: backColor,
                              border: Border(
                                top: BorderSide(
                                    width: 3.w, color: widget.accentColor),
                              ),
                            ),
                            child: Directionality(
                              textDirection: currentTextDirection,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  SizedBox(
                                    width: 5.w,
                                  ),
                                  Visibility(
                                    visible: currentTextDirection ==
                                            TextDirection.rtl
                                        ? showNext
                                        : showPrevious,
                                    child: IconButton(
                                        onPressed: () {
                                          currentTextDirection ==
                                                  TextDirection.rtl
                                              ? nextChapter()
                                              : prevChapter();
                                        },
                                        icon: Icon(
                                          currentTextDirection ==
                                                  TextDirection.rtl
                                              ? Icons.arrow_forward_ios_rounded
                                              : Icons.arrow_back_ios,
                                          size: 15.h,
                                          color: fontColor,
                                        )),
                                  ),
                                  SizedBox(
                                    width: 5.w,
                                  ),
                                  Expanded(
                                    flex: 10,
                                    child: Text(
                                      chaptersList.isNotEmpty
                                          ? chaptersList[_currentChapterIndex]
                                              .chapter
                                          : 'Loading...',
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      textDirection: currentTextDirection,
                                      style: TextStyle(
                                          fontSize: 32.sp,
                                          overflow: TextOverflow.ellipsis,
                                          fontFamily: selectedTextStyle,
                                          package: 'cosmos_epub',
                                          fontWeight: FontWeight.bold,
                                          color: fontColor),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 5.w,
                                  ),
                                  Visibility(
                                      visible: currentTextDirection ==
                                              TextDirection.rtl
                                          ? showPrevious
                                          : showNext,
                                      child: IconButton(
                                          onPressed: () {
                                            currentTextDirection ==
                                                    TextDirection.rtl
                                                ? prevChapter()
                                                : nextChapter();
                                          },
                                          icon: Icon(
                                            currentTextDirection ==
                                                    TextDirection.rtl
                                                ? Icons.arrow_back_ios
                                                : Icons
                                                    .arrow_forward_ios_rounded,
                                            size: 15.h,
                                            color: fontColor,
                                          ))),
                                  SizedBox(
                                    width: 5.w,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedContainer(
                      height: showHeader ? 50.h : 0,
                      duration: const Duration(milliseconds: 100),
                      color: backColor,
                      child: Padding(
                        padding: EdgeInsets.only(top: 3.h),
                        child: Directionality(
                          textDirection: currentTextDirection,
                          child: AppBar(
                            centerTitle: true,
                            title: Text(
                              bookTitle,
                              textDirection: currentTextDirection,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 32.sp,
                                  color: fontColor),
                            ),
                            backgroundColor: backColor,
                            shape: Border(
                                bottom: BorderSide(
                                    color: widget.accentColor, width: 3.h)),
                            elevation: 0,
                            leading: _searchController.isActive &&
                                    _searchController.results.isNotEmpty
                                ? IconButton(
                                    key: const Key('back_to_search_button'),
                                    tooltip: 'Back to search results',
                                    onPressed: () {
                                      if (_isSearchSheetOpen) {
                                        _clearSearchState();
                                        Navigator.pop(context);
                                      } else {
                                        _openSearchSheet();
                                      }
                                    },
                                    icon: Icon(
                                      Platform.isIOS || Platform.isMacOS
                                          ? Icons.manage_search
                                          : Icons.arrow_back,
                                      color: fontColor,
                                      size: 20.h,
                                    ),
                                  )
                                : IconButton(
                                    key: const Key('back_button'),
                                    onPressed: () {
                                      if (widget.onBack != null) {
                                        widget.onBack!();
                                      } else {
                                        Navigator.pop(context);
                                      }
                                    },
                                    icon: Icon(
                                      Icons.shelves,
                                      color: fontColor,
                                      size: 20.h,
                                    ),
                                  ),
                            actions: [
                              IconButton(
                                key: const Key('toc_button'),
                                onPressed: openTableOfContents,
                                icon: Icon(
                                  Icons.menu,
                                  color: fontColor,
                                  size: 20.h,
                                ),
                              ),
                              InkWell(
                                  onTap: () {
                                    updateFontSettings();
                                  },
                                  child: Container(
                                    width: 40.w,
                                    alignment: Alignment.center,
                                    child: Text(
                                      "Aa",
                                      style: TextStyle(
                                          fontSize: 24.sp,
                                          color: fontColor,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  )),
                              SizedBox(
                                width: 5.w,
                              ),
                              if (!Platform.isMacOS)
                                InkWell(
                                    onTap: () async {
                                      setState(() {
                                        showBrightnessWidget = true;
                                      });
                                      await Future.delayed(
                                          const Duration(seconds: 7));
                                      setState(() {
                                        showBrightnessWidget = false;
                                      });
                                    },
                                    child: Icon(
                                      Icons.brightness_high_sharp,
                                      size: 20.h,
                                      color: fontColor,
                                    )),
                              SizedBox(
                                width: 10.w,
                              ),
                              if (!_searchController.isActive &&
                                  !_isSearchSheetOpen)
                                IconButton(
                                  key: const Key('search_button'),
                                  onPressed: _openSearchSheet,
                                  icon: Icon(
                                    Icons.search,
                                    color: fontColor,
                                    size: 20.h,
                                  ),
                                ),
                              PopupMenuButton<String>(
                                key: const Key('reader_overflow_menu'),
                                icon: Icon(
                                  Icons.more_vert,
                                  color: fontColor,
                                  size: 20.h,
                                ),
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'notes':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => NotesListScreen(
                                            bookId: bookId,
                                            onNoteTapped: (note) {
                                              _onNoteTapped(note);
                                            },
                                          ),
                                        ),
                                      );
                                    case 'export_md':
                                      await _handleExport(
                                          'md',
                                          () => notesToMarkdown(
                                              bookTitle,
                                              HighlightStorage.getBookNotes(
                                                  bookId)));
                                    case 'export_json':
                                      await _handleExport(
                                          'json',
                                          () => notesToJson(
                                              bookTitle,
                                              HighlightStorage.getBookNotes(
                                                  bookId)));
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'notes',
                                    child: Text('Notes'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'export_md',
                                    child: Text('Export Markdown…'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'export_json',
                                    child: Text('Export JSON…'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )));
  }

  Future<void> _handleExport(
      String extension, String Function() buildContent) async {
    if (HighlightStorage.getBookNotes(bookId).isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No notes to export')),
        );
      }
      return;
    }

    final content = buildContent();

    try {
      final safeTitle = bookTitle
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'notes_${safeTitle}_$dateStr.$extension';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Notes',
        fileName: fileName,
      );

      if (path == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export cancelled')),
          );
        }
        return;
      }

      final file = File(path);
      await file.writeAsBytes(utf8.encode(content));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Notes exported to ${file.uri.pathSegments.last}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  openTableOfContents() async {
    bool? shouldUpdate = await Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ChaptersList(
                  bookId: bookId,
                  chapters: chaptersList,
                  leadingIcon: null,
                  accentColor: widget.accentColor,
                  chapterListTitle: widget.chapterListTitle,
                  currentChapterIndex: _currentChapterIndex,
                ))) ??
        false;
    if (shouldUpdate) {
      _clearSearchState();

      final progress = await bookProgress.getBookProgress(bookId);
      var index = progress.currentChapterIndex ?? 0;

      await bookProgress.setCurrentPageIndex(bookId, 0);
      reLoadChapter(index: index);
    }
  }
}
