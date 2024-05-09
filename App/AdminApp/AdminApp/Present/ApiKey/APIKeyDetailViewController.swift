import UIKit
import Combine
import Then

class APIKeyDetailViewController: UIViewController, UICollectionViewDelegate {
    var isRefreshing = false
    var buttonConfig = UIButton.Configuration.plain()
    lazy var purchaseCardButton = UIButton(configuration: buttonConfig).then{
        $0.tintColor = .LightBlue700
        $0.setImage(UIImage(systemName: "cart.badge.plus"), for: .normal)
    }
    
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout()).then {
        $0.backgroundColor = .clear
        $0.delegate = self
        $0.register(APIKeyImageCell.self, forCellWithReuseIdentifier: APIKeyImageCell.identifier)
        $0.register(SmallCellHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SmallCellHeader.identifier)
        $0.register(SmallCellFooter.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: SmallCellFooter.identifier)
        $0.register(APIKeyInfoCell.self, forCellWithReuseIdentifier: APIKeyInfoCell.identifier)
        $0.showsHorizontalScrollIndicator = false
        $0.showsVerticalScrollIndicator = false
        $0.alwaysBounceVertical = true
        
        
    }
    private var pageControl = UIPageControl().then {
        $0.currentPageIndicatorTintColor = .darkGray
        $0.pageIndicatorTintColor = .lightGray
    }
    
    enum Item: Hashable {
        case cardList(APICard)
        case actionInfo(APIKeyItem)
        case actionAnalyze(APIKeyItem)
        case actionDelete(APIKeyItem)
    }
    
    var dataSource : UICollectionViewDiffableDataSource<Section , Item>!
    enum Section : Int, CaseIterable {
        case cardSection
        case infoSection
        case analyzeSection
        case deleteSection
        var header : String{
            switch self {
            case .infoSection:
                return "키 정보"
            case .analyzeSection:
                return "비용 분석"
            case .deleteSection:
                return "키 해지"
            case .cardSection:
                return ""
            }
        }
        var footer: String {
            switch self {
            case .infoSection:
                return "API Key를 탭하여 복사할 수 있습니다. 복사한 Key는 다양한 애플리케이션에 적용하여 API 기능을 활용할 수 있습니다. 각 Key는 고유하며, 안전한 관리와 사용을 위해 Key 정보를 외부와 공유하지 마세요.\n\n"
            case .analyzeSection:
                return "API Key의 사용된 내역을 확인할 수 있습니다.\n\n얼마나 많은 요청이 이루어졌는지와 비용 등의 정보를 얻을 수 있습니다. 효율적인 관리를 위해 주기적으로 사용 상태를 확인하세요.\n\n"
            case .deleteSection:
                return "더 이상 필요하지 않은 API Key를 제거할 수 있습니다.\n\nKey 삭제는 복구할 수 없으므로 주의하여 실행해야 합니다. 삭제된 Key는 관련된 서비스에서 더 이상 작동하지 않으므로, 해당 Key가 사용되고 있는지 확인 후 진행해주세요.\n\n"
            case .cardSection:
                return "\n\n"
            }
        }
    }
    
    private var viewModel = APIKeyViewModel(ApiKeyItem: APIKeyItem.list)
    private var subscriptions: Set<AnyCancellable> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupLayout()
        setupDatasource()
        setupRefreshControl()
        bind()
        collectionView.delegate = self
        viewModel.fetchAPIKeys(firstApiKeyId: 1, size: 5)
    }
    private func bind() {
        viewModel.ApiKey
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink(receiveCompletion: { error in
                switch error {
                    
                case .finished:
                    break
                case .failure(let error):
                    switch error{
                        
                    case .encodingFailed:
                        self.showConfirmationPopup(mainText: "네트워크 오류", subText: "API KEY를 받아올 수 없습니다.\nEncodingFailed", centerButtonTitle: "확인")
                    case .networkFailure(let code):
                        self.showConfirmationPopup(mainText: "네트워크 오류", subText: "API KEY를 받아올 수 없습니다.\n\(code) NetworkFailture ", centerButtonTitle: "확인")
                    case .invalidResponse:
                        self.showConfirmationPopup(mainText: "네트워크 오류", subText: "API KEY를 받아올 수 없습니다.\ninvalidResponse", centerButtonTitle: "확인")
                    case .unknown:
                        self.showConfirmationPopup(mainText: "네트워크 오류", subText: "API KEY를 받아올 수 없습니다.\n알수없는 에러", centerButtonTitle: "확인")
                    }
                    
                }
            }, receiveValue: {  [weak self] apiKeyData in
                DispatchQueue.main.async {
                    self?.collectionView.refreshControl?.endRefreshing()
                }
                if apiKeyData.isEmpty {
                    self?.didTapPurchase()
                } else {
                    self?.collectionView.backgroundView = nil
                }
                let items = apiKeyData.map { Item.cardList($0) }
                self?.applySectionItems(items, to: .cardSection)
                self?.pageControl.numberOfPages = apiKeyData.count
                self?.pageControl.isHidden = apiKeyData.count <= 1
            })
            .store(in: &subscriptions)
        viewModel.ApiKeyItem
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] apiKeyItem in
                apiKeyItem.forEach { item in
                    switch item.content{
                    case .copyPasteAPIKey:
                        self?.applySectionItems([Item.actionAnalyze(item)], to: .infoSection)
                    case .analyzeAPIKey:
                        self?.applySectionItems([Item.actionAnalyze(item)], to: .analyzeSection)
                    case .deleteAPIKey:
                        self?.applySectionItems([Item.actionAnalyze(item)], to: .deleteSection)
                    }
                }
            }
            .store(in: &subscriptions)
        
        viewModel.eventPublisher
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    switch error{
                    case .encodingFailed:
                        self?.showConfirmationPopup(mainText: "네트워크 오류", subText: "EncodingFailed", centerButtonTitle: "확인")
                    case .networkFailure(let code):
                        self?.showConfirmationPopup(mainText: "네트워크 오류", subText: "\(code) NetworkFailture ", centerButtonTitle: "확인")
                    case .invalidResponse:
                        self?.showConfirmationPopup(mainText: "네트워크 오류", subText: "invalidResponse", centerButtonTitle: "확인")
                    case .unknown:
                        self?.showConfirmationPopup(mainText: "네트워크 오류", subText: "알수없는 에러", centerButtonTitle: "확인")
                    }
                    
                }
            } receiveValue: { message in
                self.showToastMessage(width: 290, state: .check, message: message)
            }
            .store(in: &subscriptions)
        
    }
    private func setupDatasource(){
        self.dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView, cellProvider: { collectionView, indexPath, item in
            switch item{
            case .cardList(let card):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: APIKeyImageCell.identifier, for: indexPath) as! APIKeyImageCell
                cell.configure(card)
                return cell
            case .actionInfo(let action):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: APIKeyInfoCell.identifier, for: indexPath) as! APIKeyInfoCell
                cell.configure(action)
                return cell
            case .actionAnalyze(let action):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: APIKeyInfoCell.identifier, for: indexPath) as! APIKeyInfoCell
                cell.configure(action)
                return cell
            case .actionDelete(let action):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: APIKeyInfoCell.identifier, for: indexPath) as! APIKeyInfoCell
                cell.configure(action)
                return cell
            }
        })
        dataSource.supplementaryViewProvider = { (collectionView, kind, indexPath) in
            if kind == UICollectionView.elementKindSectionHeader {
                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SmallCellHeader.identifier, for: indexPath) as? SmallCellHeader else {
                    return nil
                }
                let section = Section.allCases[indexPath.section]
                header.configure(subtitle: section.header)
                return header
            } else if kind == UICollectionView.elementKindSectionFooter {
                guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SmallCellFooter.identifier, for: indexPath) as? SmallCellFooter else {
                    return nil
                }
                let section = Section.allCases[indexPath.section]
                footer.configure(subtitle: section.footer)
                return footer
            }
            return nil
        }
    }
    private func applySectionItems(_ items: [Item], to section: Section) {
        var snapshot = dataSource.snapshot()
        
        if snapshot.sectionIdentifiers.contains(section) {
            snapshot.deleteItems(snapshot.itemIdentifiers(inSection: section))
        }
        
        if !snapshot.sectionIdentifiers.contains(section) {
            snapshot.appendSections([section])
        }
        snapshot.appendItems(items, toSection: section)
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func setupUI() {
        self.title = "API 키"
        self.navigationItem.title = "내 API 키"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: purchaseCardButton)
        self.navigationController?.navigationBar.prefersLargeTitles = false
        self.view.backgroundColor = .defaultBackgroundColor
        purchaseCardButton.addTarget(self, action: #selector(didTapPurchase), for: .touchUpInside)
    }
    
    private func setupLayout(){
        view.addSubview(collectionView)
        view.addSubview(pageControl)
        
        pageControl.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
        }
        collectionView.snp.makeConstraints {
            $0.top.equalTo(pageControl.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
    }
    
    @objc func didTapPurchase() {
        let vc = PurchaseViewController()
        vc.modalPresentationStyle = .pageSheet
        self.present(vc,animated: true)
    }
    
    private func layout() -> UICollectionViewCompositionalLayout{
        return UICollectionViewCompositionalLayout { sectionIndex , layoutEnviroment in
            let section = Section.allCases[sectionIndex]
            switch section {
            case .cardSection:
                return self.cardSectionLayout()
            case .infoSection:
                return self.actionSectionLayout()
            case .analyzeSection:
                return self.actionSectionLayout()
            case .deleteSection:
                return self.actionSectionLayout()
            }
            
        }
    }
    
    private func cardSectionLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.9), heightDimension: .estimated(250))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 20
        section.visibleItemsInvalidationHandler = { (item, offset, env) in
            let index = Int(max(0, round(offset.x / env.container.contentSize.width)))
            self.pageControl.currentPage = index
        }
        
        // 헤더 사이즈와 스티키 설정
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)
        header.pinToVisibleBounds = true  // 스크롤 시 상단에 헤더 고정
        
        // 푸터 사이즈 설정
        let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(200))
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerSize,
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom)
        
        section.boundarySupplementaryItems = [header, footer]
        return section
    }
    
    private func actionSectionLayout() -> NSCollectionLayoutSection {
        // Item
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(80))
        let itemLayout = NSCollectionLayoutItem(layoutSize: itemSize)
        
        // Group
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(80))
        let groupLayout = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [itemLayout])
        groupLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        groupLayout.interItemSpacing = .fixed(10)
        
        // Section
        let section = NSCollectionLayoutSection(group: groupLayout)
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 8, bottom: 15, trailing: 8) // 섹션과 헤더/푸터 사이 간격 조정
        section.interGroupSpacing = 10
        
        // Header and Footer
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(200))
        let footer = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: footerSize, elementKind: UICollectionView.elementKindSectionFooter, alignment: .bottom)
        
        section.boundarySupplementaryItems = [header, footer]
        return section
    }
    
    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshAPIKeys), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    @objc private func refreshAPIKeys() {
        // API Key 데이터 새로고침 로직
        viewModel.fetchAPIKeys(firstApiKeyId: 1, size: 5)
    }
    
    
}

extension ApiKeyViewController {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if pageControl.numberOfPages == 0 {
            return
        }
        let apiKeyCard = viewModel.ApiKey.value[pageControl.currentPage]
        //            print("Selected Cell at IndexPath: \(indexPath)")
        //            print("Current PageControl Index: \(pageControl.currentPage)")
        //            print("API Key Info: ID - \(apiKeyCard.id), Value - \(apiKeyCard.value)")
        let section = Section.allCases[indexPath.section]
        switch section{
            
        case .cardSection:
            //            print("card가 눌렸습니다.")
            break
        case .infoSection:
            UIPasteboard.general.string = apiKeyCard.value
            showToastMessage(width: 230, state: .check, message: "API KEY 가 복사되었어요 !")
            break
        case .analyzeSection:
            print("분석으로 이동")
            break
        case .deleteSection:
            showPopup(mainText: "API Key 삭제", subText: "Key 삭제는 복구할 수 없으므로 주의하여 실행해야 합니다.\n정말로 API Key를 삭제하시겠습니까 ?", leftButtonTitle: "취소", rightButtonTitle: "삭제", rightButtonHandler:  {
                self.viewModel.deleteAPIKey(id: apiKeyCard.id)
            })
        }
    }
}