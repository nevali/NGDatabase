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

#ifndef NGDATABASE_NGDBDRIVER_H_
# define NGDATABASE_NGDBDRIVER_H_      1

# import <Foundation/Foundation.h>

# include "NGDatabase.h"

@interface NGDBConnection (NGDBDriverMethods)

- (id) initWithOptions:(NSDictionary *)options status:(NSError **)status;
- (id) initDriverWithURL:(NSURL *)url options:(NSDictionary *)options status:(NSError **)status;
- (void *) exec:(NSString *)query flags:(NGDBExecFlags)flags status:(NSError **)status;
- (id) createResultSet:(void *)result status:(NSError **)status;
- (void) freeResult:(void *)result;
- (NSString *) intersperseQuery:(NSString *)query substituteParams:(BOOL)subParams paramsArray:(NSArray *)array addSuffix:(NSString *)suffix status:(NSError **)status;
- (NSString *)formatConstraints:(id)constraints;
- (NGDBExecFlags) execFlags;

@end

@interface NGDBStatement (NGDBDriverMethods)

- (void *)exec:(NSArray *)params flags:(NGDBExecFlags)flags status:(NSError **)status;

@end

#endif /* !NGDATABASE_NGDBDRIVER_H_ */
