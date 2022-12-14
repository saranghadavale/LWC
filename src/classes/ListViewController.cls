
public without sharing class ListViewController {
    private static final String REQUEST_URL = URL.getSalesforceBaseUrl().toExternalForm() + '/services/data/v53.0/sobjects/{0}/listviews/{1}/describe'; // {0} sObject type; {1} view list id
    private static final String WHERE_CONDITION = ' WHERE ';
    private static final String LIKE_CONDITION = ' LIKE ';
    private static final String AND_CONDITION = ' AND ';
    private static final String USING_SCOPE_CONDITION = ' USING SCOPE ';

    @AuraEnabled(cacheable=true)
    public static String getSessionId() {
        return Page.GenerateSessionId.getContent().toString().trim();
    }

    @AuraEnabled(cacheable=true)
    public static List<ListView> getListViewsBySobjectType(String sObjectType) {
        return [SELECT Id, Name, DeveloperName FROM ListView where SobjectType = :sObjectType];
    }

    @AuraEnabled(cacheable=true)
    public static List<SObject> getListViewRecords(String sObjectType, String listViewId, String searchFieldApiName, String searchRequest) {
        String query = getListViewRecordsQuery(sObjectType, listViewId);

        if (String.isBlank(query)) return null;

        if (String.isBlank(searchRequest)) {
            return executeQuery(query);
        }

        return executeQuery(getQueryWithWhereCondition(query, searchFieldApiName, searchRequest));
    }

    /********** Utility ***********************************************************************************************/

    private static String getListViewRecordsQuery(String sObjectType, String listViewId) {
        if (String.isBlank(sObjectType) || String.isBlank(listViewId)) return null;

        String formattedUrl = String.format(REQUEST_URL, new List<String>{
                sObjectType, listViewId
        });

        return (String) new RestService(formattedUrl, getSessionId())
                .get()
                .get('query');
    }

    private static List<SObject> executeQuery(String query) {
        if (String.isBlank(query)) return null;

        try {
            return Database.query(query);
        } catch (Exception ex) {
            System.debug(ex);
        }

        return null;
    }

    private static String getQueryWithWhereCondition(String query, String fieldApiName, String fieldValue) {
        if (query.containsIgnoreCase(WHERE_CONDITION)) return updateWhereConditionQuery(query, fieldApiName, fieldValue);

        return insertWhereConditionQuery(query, fieldApiName, fieldValue);
    }

    public static String updateWhereConditionQuery(String query, String fieldApiName, String fieldValue) {
        if (String.isBlank(query) || String.isBlank(fieldApiName) || String.isBlank(fieldValue)) return query;

        String changes = WHERE_CONDITION
                + fieldApiName
                + LIKE_CONDITION
                + '\'%' + String.escapeSingleQuotes(fieldValue) + '%\''
                + AND_CONDITION;

        return query.replaceAll('(?i)' + WHERE_CONDITION, changes); // ignore case
    }

    public static String insertWhereConditionQuery(String query, String fieldApiName, String fieldValue) {
        if (String.isBlank(query) || String.isBlank(fieldApiName) || String.isBlank(fieldValue)) return query;

        String searchPattern = 'FROM \\w+ ?';
        if (query.containsIgnoreCase(USING_SCOPE_CONDITION)) searchPattern = USING_SCOPE_CONDITION + '\\w+ ?';

        String changes = WHERE_CONDITION
                + fieldApiName
                + LIKE_CONDITION
                + '\'%' + String.escapeSingleQuotes(fieldValue) + '%\' ';

        List<String> regexMatches = regexPatternMatch(searchPattern, query);
        System.debug(regexMatches);
        if (regexMatches.isEmpty()) return query;

        return query.replaceAll(regexMatches[0], regexMatches[0] + changes);
    }

    public static List<String> regexPatternMatch(String patternValue, String text) {
        Pattern patternObj = Pattern.compile('(?i) ?' + patternValue);
        Matcher matcher = patternObj.matcher(text);

        List<String> matches = new List<String>();
        while (matcher.find()) {
            String groupValue = matcher.group();
            matches.add(groupValue);
        }
        return matches;
    }
}