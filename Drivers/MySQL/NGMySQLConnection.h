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

#ifndef DBCORE_NGMYSQLCONNECTION_H_
# define DBCORE_NGMYSQLCONNECTION_H_   1

# import <Foundation/Foundation.h>
# import "NGDatabase.h"
# import "NGDBDriver.h"
# include <mysql.h>

@interface NGMySQLConnection: NGDBConnection {
@private	
	MYSQL *conn;
	NSString *databaseName;
}

@end

@interface NGMySQLResultSet: NGDBResultSet {
@private
	id connection;	
	MYSQL_RES *result;
	NSArray *fieldNames;
	NSArray *fields;
	NSArray *rowArray;
	NSDictionary *rowDict;
	unsigned int cols;
	unsigned long long rows;
	unsigned long long rowIndex;
	BOOL eof;
	BOOL fetched;
	MYSQL_ROW row;
	unsigned long *lengths;	
}

- (id)initWithMySQLResult:(MYSQL_RES *)result connection:(id)conn status:(NSError **)status;

@end

#endif /* !DBCORE_NGMYSQLCONNECTION_H_ */