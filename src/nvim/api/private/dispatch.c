// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>
#include <msgpack.h>

#include "nvim/map.h"
#include "nvim/log.h"
#include "nvim/vim.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"

#include "nvim/api/buffer.h"
#include "nvim/api/tabpage.h"
#include "nvim/api/ui.h"
#include "nvim/api/vim.h"
#include "nvim/api/window.h"

static Map(String, MsgpackRpcRequestHandler) *methods = NULL;

static void rpc_add_method_handler(String method,
                                           MsgpackRpcRequestHandler handler)
{
  map_put(String, MsgpackRpcRequestHandler)(methods, method, handler);
}

/// Gets the C handler associated with a RPC method name.
MsgpackRpcRequestHandler rpc_get_method_handler(const char *name,
                                                size_t name_len)
{
  String m = { .data = (char *)name, .size = name_len };
  MsgpackRpcRequestHandler rv =
    map_get(String, MsgpackRpcRequestHandler)(methods, m);

  if (!rv.fn) {
    rv.fn = msgpack_rpc_handle_missing_method;
  }

  return rv;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "api/private/dispatch_wrappers.generated.h"
#endif
