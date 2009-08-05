/*
 * Copyright (c) 2009 Mo McRoberts.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 * 3. The names of the author(s) of this software may not be used to endorse
 * or promote products derived from this software without specific prior
 * written permission.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, 
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY 
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * AUTHORS OF THIS SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef P_NGDATABASE_H_
# define P_NGDATABASE_H_               1

# ifdef __OBJC__
#  import <Foundation/Foundation.h>
#  import "NGDatabase.h"
#  import "NGDBDriver.h"
# endif

#define VA_TO_NSARRAY(rest, array) { \
int c; \
va_list ap; \
id *objs; \
va_start(ap, rest); \
for(c = 0; c < 64 && va_arg(ap, id); c++); \
va_end(ap); \
objs = (NSObject **) alloca((c + 1) * sizeof(id)); \
va_start(ap, rest); \
for(c = 0; c < 64 && (objs[c] = va_arg(ap, id)); c++); \
va_end(ap); \
array = [[NSArray alloc] initWithObjects:objs count:c]; \
}

#define ASSIGN_ERROR(src, dest) \
if(dest) \
{ \
	*dest = src; \
} \
else if(src) \
{ \
	[src release]; \
}

#endif /* !P_NGDATABASE_H_ */
