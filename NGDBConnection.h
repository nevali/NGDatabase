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

#ifndef NGDATABASE_NGDBCONNECTION_H_
# define NGDATABASE_NGDBCONNECTION_H_  1

# import <Foundation/Foundation.h>

# include "NGDBError.h"
# include "NGDBResultSet.h"

@interface NGDBConnection: NSObject
{
@protected
	NSTimeZone *timeZone;
}

+ (id)connectionWithURL:(NSURL *)url options:(NSDictionary *)options status:(NSError **)status;
+ (id)connectionWithURLString:(NSString *)urlString options:(NSDictionary *)options status:(NSError **)status;

- (id)initWithURL:(NSURL *)url options:(NSDictionary *)options status:(NSError **)status;
- (id)initWithURLString:(NSString *)urlString options:(NSDictionary *)options status:(NSError **)status;

- (BOOL)executeSQL:(NSString *)query status:(NSError **)status, ...;
- (BOOL)executeSQL:(NSString *)query withArray:(NSArray *)params status:(NSError **)status;

- (id)query:(NSString *)query status:(NSError **)status, ...;
- (id)query:(NSString *)query withArray:(NSArray *)params status:(NSError **)result;

- (BOOL)insertInto:(NSString *)target values:(id)values status:(NSError **)status;

- (NSString *)quote:(id)value;
- (NSString *)quoteObject:(NSString *)objectName qualify:(BOOL)qualify;

- (NSString *)now;
- (NSString *)driverName;
- (NSString *)databaseName;
- (NSString *)schemaName;
- (NSTimeZone *)timeZone;
- (BOOL)connected;

- (void)setTimeZone:(NSTimeZone *)newTimeZone;

@end

#endif /* !NGDATABASE_NGDBCONNECTION_H_ */
