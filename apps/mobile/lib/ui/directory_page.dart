import 'package:flutter/material.dart';
import '../call/call_controller.dart';

class DirectoryPage extends StatefulWidget {
  final CallController controller;
  const DirectoryPage({super.key,required this.controller});
  @override State<DirectoryPage> createState()=>_DirectoryState();
}
class _DirectoryState extends State<DirectoryPage> {
  String query='';
  bool _leaving=false;
  @override void initState(){super.initState();widget.controller.addListener(_callChanged);widget.controller.refreshDirectory();}
  void _callChanged() {
    if(_leaving || ![AppCallState.incomingPending,AppCallState.connecting,AppCallState.connected,AppCallState.unconfigured,AppCallState.error].contains(widget.controller.state))return;
    setState(()=>_leaving=true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted && ModalRoute.of(context)?.isCurrent==true)Navigator.of(context).pop();
    });
  }
  @override void dispose(){widget.controller.removeListener(_callChanged);super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:widget.controller,builder:(context,_){
    final c=widget.controller;
    final entries=c.directory.where((e)=>e.label.toLowerCase().contains(query.toLowerCase())).toList();
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(
      appBar:AppBar(title:const Text('داخلی‌های شرکت'),actions:[IconButton(tooltip:'تازه‌سازی',onPressed:c.directoryLoading?null:c.refreshDirectory,icon:const Icon(Icons.refresh))]),
      body:Column(children:[Padding(padding:const EdgeInsets.all(16),child:TextField(decoration:const InputDecoration(labelText:'جست‌وجوی نام یا شماره',prefixIcon:Icon(Icons.search)),onChanged:(v)=>setState(()=>query=v))),
        if(c.directoryLoading)const LinearProgressIndicator(),
        if(c.directoryError!=null)Padding(padding:const EdgeInsets.all(16),child:Text(c.directoryError!)),
        Expanded(child:entries.isEmpty?Center(child:Text(c.directoryLoading?'در حال دریافت…':'داخلی دیگری پیدا نشد.')):ListView.builder(itemCount:entries.length,itemBuilder:(ctx,i){final e=entries[i];final own=e.extension==c.extension;return ListTile(
          leading:CircleAvatar(child:Text(e.extension)),title:Text(e.displayName.isEmpty?'داخلی ${e.extension}':e.displayName),subtitle:Text(own?'${e.extension} · حساب شما':e.extension),
          trailing:IconButton(tooltip:'تماس با ${e.extension}',icon:const Icon(Icons.call),onPressed:own||c.state!=AppCallState.idle?null:()async{
            final ok=await c.placeCall(e.extension);if(!ctx.mounted)return;
            if(ok){Navigator.of(ctx).pop();}else{ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(c.errorMessage??'تماس برقرار نشد.')));}
          }));})),
      ])));
  });
}
