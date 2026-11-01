import 'package:flutter/material.dart';
import '../call/call_controller.dart';
import '../config/app_config.dart';

class ServerSettingsPage extends StatefulWidget {
  final CallController controller;
  const ServerSettingsPage({super.key,required this.controller});
  @override State<ServerSettingsPage> createState()=>_ServerSettingsState();
}
class _ServerSettingsState extends State<ServerSettingsPage> {
  late final _address=TextEditingController(text:widget.controller.serverAddress);
  final _password=TextEditingController();
  final _form=GlobalKey<FormState>();
  bool _busy=false;
  String? _error;
  @override void dispose(){_address.dispose();_password.dispose();super.dispose();}
  Future<void> _save() async {
    if(!_form.currentState!.validate())return;
    setState((){_busy=true;_error=null;});
    try {
      await widget.controller.changeServer(_address.text.trim(),_password.text);
      if(mounted)Navigator.of(context).pop(true);
    } catch(_) {
      if(mounted)setState(()=>_error='تنظیم نشد؛ رمز دولوپر، آدرس و نبود تماس فعال را بررسی کنید. پس از تلاش ناموفق زیاد، یک دقیقه صبر کنید.');
    } finally { if(mounted)setState(()=>_busy=false); }
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(title:const Text('تنظیمات سرور')),
    body:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Form(key:_form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('برای تغییر آدرس، رمز دولوپر لازم است. پس از ذخیره باید با حساب سرور جدید دوباره وارد شوید.'),
      const SizedBox(height:16),
      TextFormField(controller:_address,enabled:!_busy,textDirection:TextDirection.ltr,decoration:const InputDecoration(labelText:'آی‌پی یا دامنه سرور',hintText:'192.168.1.151 یا phone.company.com:443'),validator:(v)=>AppConfig.validAddress(v?.trim()??'')?null:'آدرس بدون http، مسیر یا فاصله وارد کنید.'),
      const SizedBox(height:16),
      TextFormField(controller:_password,enabled:!_busy,obscureText:true,autocorrect:false,enableSuggestions:false,decoration:const InputDecoration(labelText:'رمز دولوپر'),validator:(v)=>v==null||v.isEmpty?'رمز را وارد کنید':null),
      const SizedBox(height:16),
      const Text('گواهی امن سرور باید برای همین آدرس معتبر و مورد اعتماد برنامه باشد. تغییر آدرس، بررسی امنیت اتصال را غیرفعال نمی‌کند.'),
      if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      FilledButton(onPressed:_busy?null:_save,child:Text(_busy?'در حال ذخیره…':'ذخیره و ورود دوباره')),
    ]))),
  ));
}
