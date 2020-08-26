/**
 * Author: charlie@callaway.cloud
 *  Class to find the "root" or highest ancestor of a "hierarchical" relationship
 *  (lookup or master detail pointing to the same object)
 */
public class RootSearch {
  SObjectType sobType;
  SObjectField parentField;
  String query;

  /**
   * Constructor
   * @param sobType The SObject Type to search on
   * @param parentField The Master-Detail or Lookup relationship to traverse
   */
  public RootSearch(SObjectType sobType, SObjectField parentField) {
    this.sobType = sobType;
    this.parentField = parentField;
    this.query = generateQuery();
  }

  /**
   * Given a set of ID, it will return a Map<Id,Id> where the Key is the ID passed in,
   *  and the Value is the highest parent in the hierarchy
   * @param ids the Set of records to find Roots for
   */
  public Map<Id, Id> search(Set<Id> ids) {
    Map<Id, Id> rootMap = new Map<Id, Id>();
    List<SObject> sobs = Database.query(this.query);

    Map<Id, Id> searchDeeperIds = new Map<Id, Id>();
    for (SObject sob : sobs) {
      RootSearchResult root = findRoot(sob, 1, rootMap);
      if (root.confirmed) {
        rootMap.put(sob.Id, root.rootId);
      } else {
        searchDeeperIds.put(root.rootId, sob.Id);
      }
    }
    if (searchDeeperIds.size() > 0) {
      // this will pollute rootMap with the intermediate roots
      Map<Id, Id> deepRoots = search(searchDeeperIds.keySet());
      for (Id intermediate : deepRoots.keySet()) {
        rootMap.put(searchDeeperIds.get(intermediate), deepRoots.get(intermediate));
      }
    }

    return rootMap;
  }

  private RootSearchResult findRoot(SObject sob, Integer depth, Map<Id, Id> foundRoots) {
    //check cache
    if (foundRoots.containsKey(sob.Id)) {
      return new RootSearchResult(foundRoots.get(sob.Id), true);
    }

    Boolean maxDepth = depth == 5;
    SObject parent = sob.getSObject(this.parentField);
    if (parent == null || maxDepth) {
      return new RootSearchResult(sob.Id, !maxDepth);
    } else {
      return findRoot(parent, ++depth, foundRoots);
    }
  }

  /** Example:
    SELECT
        Id,
        ParentId,
        Parent.ParentId,
        Parent.Parent.ParentId,
        Parent.Parent.Parent.ParentId,
        Parent.Parent.Parent.Parent.ParentId,
        Parent.Parent.Parent.Parent.Parent.ParentId
      FROM Account
      WHERE Id IN :ids
   */
  private String generateQuery() {
    String[] fields = HierarchicalSearchUtil.generateMaxTraverseFields(this.parentField);
    return String.format(
      'SELECT {0} \nFROM {1} \nWHERE Id IN :ids',
      new List<String>{ String.join(fields, ',\n'), this.sobType.getDescribe().getName() }
    );
  }

  private class RootSearchResult {
    public Id rootId;
    public Boolean confirmed;
    public RootSearchResult(Id rootId, Boolean confirmed) {
      this.rootId = rootId;
      this.confirmed = confirmed;
    }
  }
}