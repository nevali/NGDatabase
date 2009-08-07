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

#ifndef NGDATABASE_H_
# define NGDATABASE_H_                 1

# import <Foundation/Foundation.h>

typedef enum {
	NGDBEF_None = 0,
	NGDBEF_Unbuffered = (1<<0),
	NGDBEF_Uncached = (1<<1),
	NGDBEF_DebugLog = (1<<2)
} NGDBExecFlags;

# include "NGDBError.h"
# include "NGDBResultSet.h"
# include "NGDBConnection.h"
# include "NGDBStatement.h"

# ifdef NGDB_WEAK_IMPORTS
#  define NGDB_CONST_EXTERN_ATTRIBUTE __attribute__((weak_import))
# else
#  define NGDB_CONST_EXTERN_ATTRIBUTE
# endif

extern NSString *const NGDBErrorDomain NGDB_CONST_EXTERN_ATTRIBUTE; 
extern NSString *const NGDBNull NGDB_CONST_EXTERN_ATTRIBUTE; 
extern NSString *const NGDBDefault NGDB_CONST_EXTERN_ATTRIBUTE;

@interface NGDatabase : NSObject
{
@private
	NSMutableDictionary *driverInfo;
	NSMutableDictionary *driverClasses;
}

+ (NGDatabase *)sharedDatabaseManager;

- (BOOL)addDriverClass:(NSDictionary *)infoDictionary class:(Class)theClass bundlePath:(NSString *)path;
- (Class)driverForScheme:(NSString *)scheme;
- (id)driverProperty:(NSString *)propertyName forScheme:(NSString *)scheme;
- (NSDictionary *)driverInfoDictionaryForScheme:(NSString *)scheme;
- (BOOL)loadDriversFromPath:(NSString *)folderPath;
- (BOOL)loadDriverFromBundle:(NSString *)path;

@end

#endif /* !NGDATABASE_H_ */
