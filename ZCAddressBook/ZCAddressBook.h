//
//  ZCAddressBook.h



#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>
#import "pinyin.h"
#import <AddressBook/AddressBook.h>

enum
{
    ABHelperCanNotConncetToAddressBook,
    ABHelperExistSpecificContact,
    ABHelperNotExistSpecificContact
};typedef NSUInteger ABHelperCheckExistResultType;

@interface ZCAddressBook : NSObject
{

}
//数据
@property(nonatomic,retain)NSMutableArray*dataArray;
+ (ZCAddressBook*)instance;

#pragma  mark  添加联系人
- (BOOL)addContactName:(NSString*)name phoneNum:(NSString*)num withLabel:(NSString*)label;

#pragma mark 查找通讯录中是否有这个联系人
- (ABHelperCheckExistResultType)existPhone:(NSString*)phoneNum;

#pragma mark 获取通讯录内容
-(NSMutableArray*)getContacts:(NSArray *)searchKeys;//searchKeys 要检索的内容，如kABPersonFirstNameProperty等

#pragma mark 获取排序后的通讯录内容
-(NSArray*)sortedContacts:(NSArray *)searchKeys;//searchKeys 要检索的内容
#pragma mark 获取排序后的通讯录内容
-(NSDictionary*)sortedContactsWithKeys:(NSArray *)searchKeys;//searchKeys 要检索的内容

@end
