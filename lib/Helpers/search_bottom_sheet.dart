import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../Model/chapter_model.dart';
import '../Model/search_controller.dart';
import '../Model/search_result.dart';

class SearchBottomSheet extends StatefulWidget {
  final List<LocalChapterModel> chapters;
  final EpubSearchController searchController;
  final Color accentColor;
  final Color backgroundColor;
  final Color fontColor;
  final void Function(SearchResult) onResultTapped;

  const SearchBottomSheet({
    super.key,
    required this.chapters,
    required this.searchController,
    required this.accentColor,
    required this.backgroundColor,
    required this.fontColor,
    required this.onResultTapped,
  });

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final _searchFieldController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.searchController.setChapters(widget.chapters);
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFieldController.dispose();
    _focusNode.dispose();
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.searchController.search(value);
    });
  }

  void _clearSearch() {
    _searchFieldController.clear();
    widget.searchController.clear();
  }

  void _onResultTap(SearchResult result) {
    widget.onResultTapped(result);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(top: 8.h, bottom: 8.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: TextField(
                  key: const Key('search_input_field'),
                  controller: _searchFieldController,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: TextStyle(
                    color: widget.fontColor,
                    fontSize: 16.sp,
                  ),
                  cursorColor: widget.accentColor,
                  decoration: InputDecoration(
                    hintText: 'Search in book...',
                    hintStyle: TextStyle(
                      color: widget.fontColor.withValues(alpha: 0.5),
                      fontSize: 16.sp,
                    ),
                    filled: true,
                    fillColor: widget.fontColor.withValues(alpha: 0.08),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide:
                          BorderSide(color: widget.accentColor, width: 1.5),
                    ),
                    suffixIcon: _searchFieldController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: widget.fontColor.withValues(alpha: 0.6),
                              size: 20.sp,
                            ),
                            onPressed: _clearSearch,
                          )
                        : null,
                  ),
                  onChanged: _onSearchTextChanged,
                ),
              ),
              SizedBox(height: 8.h),
              Expanded(child: _buildContent()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final controller = widget.searchController;

    if (controller.isLoading) {
      return Center(
        child: Platform.isIOS
            ? CupertinoActivityIndicator(color: widget.accentColor)
            : CircularProgressIndicator(color: widget.accentColor),
      );
    }

    if (controller.errorMessage != null && controller.results.isEmpty) {
      return Center(
        child: Text(
          controller.errorMessage!,
          style: TextStyle(
            color: widget.fontColor.withValues(alpha: 0.7),
            fontSize: 15.sp,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (controller.results.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(
            color: widget.fontColor.withValues(alpha: 0.7),
            fontSize: 15.sp,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      key: const Key('search_results_list'),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: controller.results.length,
      itemBuilder: (context, index) {
        final result = controller.results[index];
        return _buildResultItem(result);
      },
    );
  }

  Widget _buildResultItem(SearchResult result) {
    final chapter = widget.chapters.length > result.chapterIndex
        ? widget.chapters[result.chapterIndex]
        : null;
    final chapterName = chapter != null
        ? chapter.chapter
        : 'Chapter ${result.chapterIndex + 1}';

    return InkWell(
      onTap: () => _onResultTap(result),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapterName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: widget.accentColor,
              ),
            ),
            SizedBox(height: 2.h),
            RichText(
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14.sp,
                  color: widget.fontColor.withValues(alpha: 0.5),
                ),
                children: [
                  if (result.contextBefore.isNotEmpty)
                    TextSpan(text: result.contextBefore),
                  TextSpan(
                    text: result.matchedText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.fontColor,
                    ),
                  ),
                  if (result.contextAfter.isNotEmpty)
                    TextSpan(text: result.contextAfter),
                ],
              ),
            ),
            SizedBox(height: 4.h),
            Divider(
                height: 1.h, color: widget.fontColor.withValues(alpha: 0.1)),
          ],
        ),
      ),
    );
  }
}
