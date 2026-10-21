rockspec_format = '3.0'
package = 'sbarlua'
version = '0.1.0-2'
source = {
  url = 'https://github.com/FelixKratz/SbarLua/archive/dba9cc421b868c918d5c23c408544a28aadf2f2f.tar.gz',
  dir = 'SbarLua-dba9cc421b868c918d5c23c408544a28aadf2f2f',
}
description = {
  summary = 'Pinned SbarLua API for the dotfiles SketchyBar configuration',
  homepage = 'https://github.com/FelixKratz/SbarLua',
  license = 'GPL-3.0',
}
supported_platforms = {'macosx'}
dependencies = {'lua >= 5.5, < 5.6'}
build = {
  type = 'builtin',
  -- Restore blank context lines at load time, avoiding trailing spaces here.
  patches = {['callback-lifecycle.patch'] = ([=[
--- a/src/sketchybar.c
+++ b/src/sketchybar.c
@@ -79,6 +79,7 @@
   char message_format[message_length + 1];
   memcpy(message_format, message, message_length);
   message_format[message_length] = '\0';
+  if (stack) free(message);
   char* response = mach_send_message(g_port,
                                      message_format,
                                      message_length + 1,
@@ -237,7 +238,9 @@
     int exit_code = 0;
     memcpy(&exit_code, message + 1 + sizeof(int), sizeof(int));
     char* response = message + 1 + 2*sizeof(int);
+    int stack_top = lua_gettop(g_state);
     lua_rawgeti(g_state, LUA_REGISTRYINDEX, callback_ref);
+    luaL_unref(g_state, LUA_REGISTRYINDEX, callback_ref);
     if (!json_to_lua_table(g_state, response)) {
       lua_pushstring(g_state, response);
     }
@@ -250,8 +253,10 @@
       printf("[!] Lua: %s\n", lua_tostring(g_state, -1));
     }
     transaction_commit(g_state);
+    lua_settop(g_state, stack_top);
     return;
   }
+  int stack_top = lua_gettop(g_state);
   env env = message;
   char* name = env_get_value_for_key(env, "NAME");
   char* sender = env_get_value_for_key(env, "SENDER");
@@ -284,6 +289,7 @@
         printf("[!] Lua: %s\n", lua_tostring(g_state, -1));
       }
       transaction_commit(g_state);
+      lua_settop(g_state, stack_top);
       break;
     }
   }
@@ -307,6 +313,9 @@
   stack_push(stack, ADD);
   sketchybar_call_log_and_cleanup(stack);

+  // Each event owns a reference, including a multi-event subscription.
+  lua_rawgeti(g_state, LUA_REGISTRYINDEX, callback_ref);
+  callback_ref = luaL_ref(g_state, LUA_REGISTRYINDEX);
   int index = -1;
   for (int i = 0; i < g_callbacks.num_callbacks; i++) {
     if (strcmp(g_callbacks.callbacks[i]->name, name) == 0
@@ -327,6 +336,7 @@
     callback->callback_ref = callback_ref;
     g_callbacks.callbacks[g_callbacks.num_callbacks - 1] = callback;
   } else {
+    luaL_unref(g_state, LUA_REGISTRYINDEX, g_callbacks.callbacks[index]->callback_ref);
     g_callbacks.callbacks[index]->callback_ref = callback_ref;
   }

@@ -368,6 +378,7 @@
     }
     stack_destroy(stack);
   }
+  luaL_unref(state, LUA_REGISTRYINDEX, callback_ref);
   return 0;
 }

@@ -613,7 +624,21 @@
   stack_push(stack, name);
   stack_push(stack, REMOVE);
   sketchybar_call_log_and_cleanup(stack);
-  return 0;}
+  for (uint32_t i = 0; i < g_callbacks.num_callbacks;) {
+    struct callback* callback = g_callbacks.callbacks[i];
+    if (strcmp(callback->name, name) != 0) { i++; continue; }
+    luaL_unref(state, LUA_REGISTRYINDEX, callback->callback_ref);
+    free(callback->name);
+    free(callback->event);
+    free(callback);
+    g_callbacks.callbacks[i] = g_callbacks.callbacks[--g_callbacks.num_callbacks];
+  }
+  if (!g_callbacks.num_callbacks) {
+    free(g_callbacks.callbacks);
+    g_callbacks.callbacks = NULL;
+  }
+  return 0;
+}

 static void orphan_check() {
   if (getppid() == 1) exit(0);
@@ -766,7 +791,9 @@
 void delay_callback(CFRunLoopTimerRef timer, void* context) {
   int callback_ref = (int)(intptr_t)context;

+  int stack_top = lua_gettop(g_state);
   lua_rawgeti(g_state, LUA_REGISTRYINDEX, callback_ref);
+  luaL_unref(g_state, LUA_REGISTRYINDEX, callback_ref);
   transaction_create(g_state);
   int error = lua_pcall(g_state, 0, 0, 0);

@@ -775,6 +802,7 @@
   }

   transaction_commit(g_state);
+  lua_settop(g_state, stack_top);
 }

 int delay(lua_State* state) {
]=]):gsub('\n\n', '\n \n')},
  modules = {
    sketchybar = {
      sources = {'src/sketchybar.c', 'src/parsing.c', 'src/cJSON.c'},
      incdirs = {'src'},
    },
  },
}
